import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/context.dart';
import 'package:prism_ui/divider.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/l10n.dart';
import 'package:prism_ui/press_region.dart';
import 'package:prism_ui/scroll_behavior.dart';
import 'package:prism_ui/shape.dart';
import 'package:prism_ui/surface.dart';
import 'package:prism_ui/theme_data.dart';
import 'package:prism_ui/tooltip.dart';
import 'package:prism_ui/typography.dart';

const _compactWidth = 48.0;
const _expandedWidth = 220.0;
const _itemSize = 40.0;
const _itemGap = 4.0;
const _toggleGap = 8.0;
const _verticalInset = 4.0;
const _maxSideInset = 12.0;
const _iconSize = 24.0;
const _labelGap = 12.0;
const _indicatorWidth = 3.0;
const _indicatorHeight = 16.0;
const _expandDuration = Duration(milliseconds: 250);
const _indicatorDuration = Duration(milliseconds: 320);
final _itemShape = AppShape.all(10);

const _sectionGap = 12.0;
const _sectionTitleHeight = 28.0;
const _sectionDuration = Duration(milliseconds: 220);
const _chevronDuration = Duration(milliseconds: 200);
const _chevronSize = 10.0;
const _badgeHeight = 18.0;
const _dotSize = 8.0;
const _compactDotInset = 6.0;
const _footerGap = 8.0;
const _separatorWidth = 16.0;
const _badgeAmber = Color(0xFFB25E00);
const _badgeRed = Color(0xFFB3261E);
const _sectionTitleColor = Color(0xFF8E8C94);

/// What a row has to tell before it is opened: a count of updates, an error,
/// or both, in which case only the error shows.
@immutable
class SidebarBadge {
  const SidebarBadge({this.count = 0, this.error = false, this.semanticLabel});

  /// What a collapsed section shows for its rows: an error from any of them
  /// over the sum of their counts.
  static SidebarBadge? merge(Iterable<SidebarBadge?> badges) {
    var count = 0;
    var error = false;
    final labels = <String>[];
    for (final badge in badges) {
      if (badge == null || badge.isEmpty) {
        continue;
      }
      count += badge.count;
      error |= badge.error;
      if (badge.semanticLabel case final label?) {
        labels.add(label);
      }
    }
    if (count == 0 && !error) {
      return null;
    }
    return SidebarBadge(
      count: count,
      error: error,
      semanticLabel: labels.isEmpty ? null : labels.join(', '),
    );
  }

  final int count;
  final bool error;
  final String? semanticLabel;

  bool get isEmpty => count <= 0 && !error;

  @override
  bool operator ==(Object other) =>
      other is SidebarBadge &&
      other.count == count &&
      other.error == error &&
      other.semanticLabel == semanticLabel;

  @override
  int get hashCode => Object.hash(count, error, semanticLabel);
}

class SidebarDestination {
  const SidebarDestination({
    required this.glyph,
    required this.label,
    this.badge,
  });

  final Glyph glyph;
  final String label;
  final SidebarBadge? badge;
}

/// A run of [length] consecutive destinations under [title]. An untitled
/// section has no heading and cannot collapse. The compact sidebar shows a
/// rule in place of each title and never hides a row.
@immutable
class SidebarSection {
  const SidebarSection({
    this.title,
    required this.length,
    this.collapsed = false,
    this.onToggle,
    this.semanticLabel,
  });

  final String? title;
  final int length;
  final bool collapsed;
  final VoidCallback? onToggle;

  /// Read for the heading in place of [title], which it should name along
  /// with whether the section is open.
  final String? semanticLabel;
}

/// Where the sidebar cannot widen in place, [onToggle] is null and the toggle
/// opens the expanded pane over the content instead.
///
/// [windowControls] is the area native window buttons cover at the top start
/// corner; the pane keeps it clear and never gets narrower than it.
class NavigationSidebar extends StatefulWidget {
  const NavigationSidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.expanded,
    required this.onSelected,
    this.onToggle,
    this.windowControls = Size.zero,
    this.sections,
    this.pinnedCount = 0,
  });

  final List<SidebarDestination> destinations;

  /// Partitions every destination but the last [pinnedCount], in order; null
  /// leaves them all in one untitled section.
  final List<SidebarSection>? sections;

  /// Destinations at the end that stay at the foot of the pane, below a rule,
  /// while the rest scroll.
  final int pinnedCount;
  final int selectedIndex;
  final bool expanded;
  final ValueChanged<int> onSelected;
  final VoidCallback? onToggle;
  final Size windowControls;

  @override
  State<NavigationSidebar> createState() => _NavigationSidebarState();
}

class _NavigationSidebarState extends State<NavigationSidebar>
    with SingleTickerProviderStateMixin {
  final _overlayController = OverlayPortalController();
  late final AnimationController _overlayExpansion = AnimationController(
    vsync: this,
    duration: _expandDuration,
  );
  late final CurvedAnimation _overlayProgress = CurvedAnimation(
    parent: _overlayExpansion,
    curve: Easing.standard,
  );

  @override
  void didUpdateWidget(covariant NavigationSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onToggle != null && _overlayController.isShowing) {
      _overlayExpansion.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _hideIfDismissed());
    }
  }

  void _handleToggle() {
    final onToggle = widget.onToggle;
    if (onToggle != null) {
      onToggle();
    } else if (_overlayExpansion.isForwardOrCompleted) {
      _closeOverlay();
    } else {
      _overlayController.show();
      _overlayExpansion.forward();
    }
  }

  void _closeOverlay() {
    _overlayExpansion.reverse().whenCompleteOrCancel(_hideIfDismissed);
  }

  void _hideIfDismissed() {
    if (mounted && _overlayExpansion.isDismissed) {
      _overlayController.hide();
    }
  }

  @override
  void dispose() {
    _overlayProgress.dispose();
    _overlayExpansion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _overlayController,
      overlayChildBuilder: (context, info) {
        return _SidebarOverlay(
          anchor: MatrixUtils.transformRect(
            info.childPaintTransform,
            Offset.zero & info.childSize,
          ),
          overlayWidth: info.overlaySize.width,
          progress: _overlayProgress,
          onDismiss: _closeOverlay,
          builder: (progress) => Padding(
            padding: safePadding,
            child: _SidebarPane(
              progress: progress,
              windowControls: widget.windowControls,
              expanded: true,
              destinations: widget.destinations,
              sections: widget.sections,
              pinnedCount: widget.pinnedCount,
              selectedIndex: widget.selectedIndex,
              onSelected: (index) {
                widget.onSelected(index);
                _closeOverlay();
              },
              onToggle: _closeOverlay,
            ),
          ),
        );
      },
      child: SafeArea(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: widget.expanded ? 1.0 : 0.0),
          duration: _expandDuration,
          curve: Easing.standard,
          builder: (context, progress, _) => _SidebarPane(
            progress: progress,
            windowControls: widget.windowControls,
            expanded: widget.expanded,
            destinations: widget.destinations,
            sections: widget.sections,
            pinnedCount: widget.pinnedCount,
            selectedIndex: widget.selectedIndex,
            onSelected: widget.onSelected,
            onToggle: _handleToggle,
          ),
        ),
      ),
    );
  }
}

class _SidebarOverlay extends StatelessWidget {
  const _SidebarOverlay({
    required this.anchor,
    required this.overlayWidth,
    required this.progress,
    required this.onDismiss,
    required this.builder,
  });

  final Rect anchor;
  final double overlayWidth;
  final Animation<double> progress;
  final VoidCallback onDismiss;
  final Widget Function(double progress) builder;

  @override
  Widget build(BuildContext context) {
    final isLtr = Directionality.of(context) == TextDirection.ltr;
    final colorScheme = context.colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        Positioned(
          left: isLtr ? anchor.left : null,
          right: isLtr ? null : overlayWidth - anchor.right,
          top: anchor.top,
          height: anchor.height,
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
            },
            child: Actions(
              actions: {
                DismissIntent: CallbackAction<DismissIntent>(
                  onInvoke: (_) {
                    onDismiss();
                    return null;
                  },
                ),
              },
              child: FocusScope(
                autofocus: true,
                child: Surface(
                  color: colorScheme.chromeSurface,
                  shape: BorderDirectional(
                    end: Divider.createBorderSide(context),
                  ),
                  elevation: 8,
                  shadowColor: colorScheme.shadow,
                  child: AnimatedBuilder(
                    animation: progress,
                    builder: (_, _) => builder(progress.value),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarColors {
  _SidebarColors(ColorScheme scheme)
    : selectedFill = scheme.onSurface.withValues(alpha: 0.08),
      label = scheme.onSurface,
      icon = scheme.onSurfaceVariant,
      indicator = scheme.primary,
      sectionRule = scheme.brightness == Brightness.dark
          ? scheme.onSurface.withValues(alpha: 0.16)
          : const Color(0xFFD3D1D8),
      footerRule = scheme.brightness == Brightness.dark
          ? scheme.onSurface.withValues(alpha: 0.12)
          : const Color(0xFFDCDAE0),
      overlay = WidgetStateProperty.fromMap({
        WidgetState.pressed: scheme.onSurface.withValues(alpha: 0.06),
        WidgetState.focused: scheme.onSurface.withValues(alpha: 0.1),
        WidgetState.hovered: scheme.onSurface.withValues(alpha: 0.04),
        WidgetState.any: Colors.transparent,
      });

  final Color selectedFill;
  final Color label;
  final Color icon;
  final Color indicator;
  final Color sectionRule;
  final Color footerRule;
  final WidgetStateProperty<Color> overlay;
}

class _SidebarPane extends StatefulWidget {
  const _SidebarPane({
    required this.progress,
    required this.windowControls,
    required this.expanded,
    required this.destinations,
    required this.sections,
    required this.pinnedCount,
    required this.selectedIndex,
    required this.onSelected,
    required this.onToggle,
  });

  final double progress;
  final Size windowControls;
  final bool expanded;
  final List<SidebarDestination> destinations;
  final List<SidebarSection>? sections;
  final int pinnedCount;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onToggle;

  @override
  State<_SidebarPane> createState() => _SidebarPaneState();
}

class _SidebarPaneState extends State<_SidebarPane>
    with TickerProviderStateMixin {
  final List<AnimationController> _openings = [];
  final List<CurvedAnimation> _curves = [];
  Listenable _layout = const _NoListenable();

  int get _pinnedCount =>
      widget.pinnedCount.clamp(0, widget.destinations.length);

  List<SidebarSection> get _sections =>
      widget.sections ??
      [SidebarSection(length: widget.destinations.length - _pinnedCount)];

  @override
  void initState() {
    super.initState();
    _syncOpenings(animate: false);
  }

  @override
  void didUpdateWidget(covariant _SidebarPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncOpenings(animate: true);
  }

  void _syncOpenings({required bool animate}) {
    final sections = _sections;
    var changed = false;
    while (_openings.length > sections.length) {
      _curves.removeLast().dispose();
      _openings.removeLast().dispose();
      changed = true;
    }
    while (_openings.length < sections.length) {
      final controller = AnimationController(
        vsync: this,
        duration: _sectionDuration,
        value: sections[_openings.length].collapsed ? 0 : 1,
      );
      _openings.add(controller);
      _curves.add(CurvedAnimation(parent: controller, curve: Curves.ease));
      changed = true;
    }
    if (changed) {
      _layout = Listenable.merge(_openings);
    }
    final reduceMotion =
        animate && (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    for (final (index, section) in sections.indexed) {
      final target = section.collapsed ? 0.0 : 1.0;
      final controller = _openings[index];
      if (controller.value == target && !controller.isAnimating) {
        continue;
      }
      if (animate && !reduceMotion) {
        controller.animateTo(target);
      } else {
        controller.value = target;
      }
    }
  }

  @override
  void dispose() {
    for (final curve in _curves) {
      curve.dispose();
    }
    for (final controller in _openings) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final expanded = widget.expanded;
    final destinations = widget.destinations;
    final selectedIndex = widget.selectedIndex;
    final colors = _SidebarColors(context.colorScheme);
    final fontSize = AppTextStyle.subheadline.size;
    final labelOpacity = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
    final compactWidth = math.max(_compactWidth, widget.windowControls.width);
    final sideInset = math.min(_maxSideInset, (compactWidth - _itemSize) / 2);
    final itemWidth = compactWidth - sideInset * 2;
    final iconInset = (itemWidth - _iconSize) / 2;
    final itemHeight =
        _itemSize + MediaQuery.textScalerOf(context).scale(fontSize) - fontSize;
    final stride = itemHeight + _itemGap;
    final rowWidth = _expandedWidth - sideInset * 2;
    final labelStyle = AppTextStyle.subheadline
        .of(context)
        .copyWith(color: colors.label);
    final labelWidth = rowWidth - iconInset - _iconSize - _labelGap * 2;
    String rowTooltip(String label) =>
        expanded &&
            progress == 1 &&
            _fitsOneLine(context, label, labelStyle, labelWidth)
        ? ''
        : label;
    final sections = _sections;
    final scrolled = destinations.length - _pinnedCount;
    final titleHeight = lerpDouble(
      _sectionGap,
      _sectionGap + _sectionTitleHeight,
      progress,
    )!;

    Widget row(int index) {
      final destination = destinations[index];
      return _SidebarButton(
        key: ValueKey(destination.label),
        colors: colors,
        height: itemHeight,
        sideInset: sideInset,
        selected: index == selectedIndex,
        tooltip: rowTooltip(destination.label),
        badge: destination.badge,
        badgeOpacity: labelOpacity,
        onTap: () => widget.onSelected(index),
        child: _DestinationRow(
          destination: destination,
          selected: index == selectedIndex,
          width: rowWidth,
          iconInset: iconInset,
          style: labelStyle,
          labelOpacity: labelOpacity,
        ),
      );
    }

    // Rows in a section that collapses only while the pane is wide: a
    // compact sidebar shows every row.
    double openOf(int section) =>
        1 - (1 - _curves[section].value) * progress.clamp(0.0, 1.0);

    double rowTop(int index) {
      var top = 0.0;
      var start = 0;
      for (final (i, section) in sections.indexed) {
        final header = section.title == null ? 0.0 : titleHeight;
        if (index < start + section.length) {
          return top + header + (index - start) * stride;
        }
        top += header + section.length * stride * openOf(i);
        start += section.length;
      }
      return top;
    }

    double selectedOpen() {
      var start = 0;
      for (final (i, section) in sections.indexed) {
        if (selectedIndex < start + section.length) {
          return openOf(i);
        }
        start += section.length;
      }
      return 1;
    }

    return SizedBox(
      width: lerpDouble(compactWidth, _expandedWidth, progress),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: widget.windowControls.height + _verticalInset),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _SidebarButton(
              colors: colors,
              height: itemHeight,
              sideInset: sideInset,
              tooltip: expanded
                  ? UiLocalizations.of(context).showLess
                  : UiLocalizations.of(context).showMore,
              tooltipIsLabel: true,
              onTap: widget.onToggle,
              child: SizedBox(
                width: itemWidth,
                child: Center(child: GlyphIcon(Glyphs.sidebar(progress))),
              ),
            ),
          ),
          const SizedBox(height: _toggleGap),
          Expanded(
            child: ScrollConfiguration(
              behavior: const BaseScrollBehavior(),
              child: SingleChildScrollView(
                child: AnimatedBuilder(
                  animation: _layout,
                  builder: (context, _) {
                    var start = 0;
                    final children = <Widget>[];
                    for (final (i, section) in sections.indexed) {
                      final end = start + section.length;
                      final rows = [for (var r = start; r < end; r++) row(r)];
                      final merged = section.collapsed
                          ? SidebarBadge.merge([
                              for (var r = start; r < end; r++)
                                destinations[r].badge,
                            ])
                          : null;
                      start = end;
                      if (section.title case final title?) {
                        children.add(
                          _SectionHeading(
                            title: title,
                            semanticLabel: section.semanticLabel ?? title,
                            collapsed: section.collapsed,
                            onToggle: section.onToggle,
                            badge: merged,
                            height: titleHeight,
                            progress: progress,
                            labelOpacity: labelOpacity,
                            sideInset: sideInset,
                            iconInset: iconInset,
                            compactWidth: compactWidth,
                            rowWidth: rowWidth,
                            colors: colors,
                          ),
                        );
                      }
                      final open = openOf(i);
                      children.add(
                        ClipRect(
                          child: Align(
                            alignment: AlignmentDirectional.topStart,
                            heightFactor: open,
                            child: ExcludeFocus(
                              excluding: open == 0,
                              child: ExcludeSemantics(
                                excluding: open == 0,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: rows,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        ),
                        if (selectedIndex < scrolled)
                          _SelectionIndicator(
                            color: colors.indicator,
                            index: selectedIndex,
                            start: sideInset,
                            rowTop: rowTop,
                            rowHeight: stride,
                            opacity: selectedOpen(),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          if (_pinnedCount > 0) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: sideInset),
              child: SizedBox(
                height: 1,
                child: ColoredBox(color: colors.footerRule),
              ),
            ),
            const SizedBox(height: _footerGap - _itemGap / 2),
            Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var index = scrolled;
                      index < destinations.length;
                      index++
                    )
                      row(index),
                  ],
                ),
                if (selectedIndex >= scrolled &&
                    selectedIndex < destinations.length)
                  _SelectionIndicator(
                    color: colors.indicator,
                    index: selectedIndex - scrolled,
                    start: sideInset,
                    rowTop: (index) => index * stride,
                    rowHeight: stride,
                  ),
              ],
            ),
            const SizedBox(height: _footerGap - _itemGap / 2 - _verticalInset),
          ],
          const SizedBox(height: _verticalInset),
        ],
      ),
    );
  }
}

class _NoListenable implements Listenable {
  const _NoListenable();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// A section's title, which opens and closes it; while closed it carries the
/// badges of its rows. Narrowed to icons it is only a short rule.
class _SectionHeading extends StatefulWidget {
  const _SectionHeading({
    required this.title,
    required this.semanticLabel,
    required this.collapsed,
    required this.onToggle,
    required this.badge,
    required this.height,
    required this.progress,
    required this.labelOpacity,
    required this.sideInset,
    required this.iconInset,
    required this.compactWidth,
    required this.rowWidth,
    required this.colors,
  });

  final String title;
  final String semanticLabel;
  final bool collapsed;
  final VoidCallback? onToggle;
  final SidebarBadge? badge;
  final double height;
  final double progress;
  final double labelOpacity;
  final double sideInset;
  final double iconInset;
  final double compactWidth;
  final double rowWidth;
  final _SidebarColors colors;

  @override
  State<_SectionHeading> createState() => _SectionHeadingState();
}

class _SectionHeadingState extends State<_SectionHeading> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final labelOpacity = widget.labelOpacity;
    final interactive = widget.onToggle != null && labelOpacity > 0;
    final style = AppTextStyle.caption1
        .of(context, emphasized: true)
        .copyWith(color: _sectionTitleColor);
    final badge = widget.badge;
    final heading = Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.sideInset),
      child: SizedBox(
        height: _sectionTitleHeight,
        child: ClipRect(
          child: OverflowBox(
            alignment: AlignmentDirectional.centerStart,
            minWidth: widget.rowWidth,
            maxWidth: widget.rowWidth,
            child: Row(
              children: [
                SizedBox(width: widget.iconInset),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
                if (badge != null) ...[
                  _Badge(badge: badge),
                  const SizedBox(width: 6),
                ],
                AnimatedOpacity(
                  opacity: _hovered || _focused ? 1 : 0,
                  duration: _chevronDuration,
                  child: AnimatedRotation(
                    turns: widget.collapsed ? -0.25 : 0,
                    duration: _chevronDuration,
                    curve: Curves.ease,
                    child: const GlyphIcon(
                      Glyphs.chevronDown,
                      size: _chevronSize,
                      color: _sectionTitleColor,
                    ),
                  ),
                ),
                const SizedBox(width: _labelGap),
              ],
            ),
          ),
        ),
      ),
    );
    final rule = Center(
      child: SizedBox(
        width: _separatorWidth,
        height: 1,
        child: ColoredBox(color: colors.sectionRule),
      ),
    );
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          if (labelOpacity < 1)
            PositionedDirectional(
              start: 0,
              width: widget.compactWidth,
              top: 0,
              height: _sectionGap,
              child: Opacity(opacity: 1 - labelOpacity, child: rule),
            ),
          if (labelOpacity > 0)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              height: _sectionTitleHeight,
              child: Opacity(
                opacity: labelOpacity,
                child: Semantics(
                  container: true,
                  button: true,
                  expanded: !widget.collapsed,
                  label: widget.semanticLabel,
                  // The press region's own action goes with the semantics
                  // this drops.
                  onTap: interactive ? widget.onToggle : null,
                  excludeSemantics: true,
                  child: FocusRing(
                    shape: _itemShape,
                    child: PressRegion(
                      onTap: interactive ? widget.onToggle : null,
                      onHover: (value) => setState(() => _hovered = value),
                      onFocusChange: (value) =>
                          setState(() => _focused = value),
                      canRequestFocus: interactive,
                      shape: _itemShape,
                      mouseCursor: SystemMouseCursors.basic,
                      child: heading,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.badge});

  final SidebarBadge badge;

  @override
  Widget build(BuildContext context) {
    if (badge.error) {
      return const _Dot(color: _badgeRed);
    }
    return Container(
      height: _badgeHeight,
      constraints: const BoxConstraints(minWidth: _badgeHeight),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: const ShapeDecoration(
        color: _badgeAmber,
        shape: AppShape.full,
      ),
      child: Text(
        '${badge.count}',
        maxLines: 1,
        style: AppTextStyle.caption2
            .of(context, emphasized: true)
            .copyWith(color: const Color(0xFFFFFFFF), height: 1),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(color: color, shape: AppShape.circle),
      child: const SizedBox.square(dimension: _dotSize),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    super.key,
    required this.colors,
    required this.height,
    required this.sideInset,
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.selected,
    this.tooltipIsLabel = false,
    this.badge,
    this.badgeOpacity = 1,
  });

  final _SidebarColors colors;
  final double height;
  final double sideInset;
  final bool? selected;
  final String tooltip;
  final bool tooltipIsLabel;
  final VoidCallback onTap;
  final Widget child;

  /// Trails the label while it shows and turns into a dot on the icon's
  /// corner as the pane narrows.
  final SidebarBadge? badge;
  final double badgeOpacity;

  @override
  Widget build(BuildContext context) {
    final badge = this.badge;
    final shown = badge == null || badge.isEmpty ? null : badge;
    var content = child;
    if (shown != null) {
      content = Stack(
        children: [
          child,
          if (badgeOpacity > 0)
            PositionedDirectional(
              end: _labelGap,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: badgeOpacity,
                  child: _Badge(badge: shown),
                ),
              ),
            ),
          if (badgeOpacity < 1)
            PositionedDirectional(
              top: _compactDotInset,
              start: _itemSize - _compactDotInset - _dotSize,
              child: Opacity(
                opacity: 1 - badgeOpacity,
                child: _Dot(color: shown.error ? _badgeRed : _badgeAmber),
              ),
            ),
        ],
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: sideInset,
        vertical: _itemGap / 2,
      ),
      child: Semantics(
        container: true,
        button: true,
        selected: selected,
        value: shown?.semanticLabel,
        child: FocusRing(
          shape: _itemShape,
          child: PressRegion(
            onTap: onTap,
            shape: _itemShape,
            fill: selected == true ? colors.selectedFill : null,
            overlay: colors.overlay,
            mouseCursor: SystemMouseCursors.basic,
            child: Tooltip(
              message: tooltip,
              excludeFromSemantics: !tooltipIsLabel,
              child: IconTheme.merge(
                data: IconThemeData(size: _iconSize, color: colors.icon),
                child: SizedBox(height: height, child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _fitsOneLine(
  BuildContext context,
  String text,
  TextStyle? style,
  double width,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
  )..layout(maxWidth: width);
  final fits = !painter.didExceedMaxLines;
  painter.dispose();
  return fits;
}

/// The row lays out at the expanded width whatever the pane's current width,
/// so the label is clipped rather than reflowed while the pane animates.
class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.destination,
    required this.selected,
    required this.width,
    required this.iconInset,
    required this.style,
    required this.labelOpacity,
  });

  final SidebarDestination destination;
  final bool selected;
  final double width;
  final double iconInset;
  final TextStyle? style;
  final double labelOpacity;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: OverflowBox(
        alignment: AlignmentDirectional.centerStart,
        minWidth: width,
        maxWidth: width,
        child: Row(
          children: [
            SizedBox(width: iconInset),
            AnimatedGlyph(glyph: destination.glyph, filled: selected),
            const SizedBox(width: _labelGap),
            Expanded(
              child: Opacity(
                opacity: labelOpacity,
                alwaysIncludeSemantics: true,
                child: Text(
                  destination.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
            const SizedBox(width: _labelGap),
          ],
        ),
      ),
    );
  }
}

/// The indicator moves by stretching toward the new row before its trailing
/// edge catches up, rather than sliding at a fixed size.
class _SelectionIndicator extends StatefulWidget {
  const _SelectionIndicator({
    required this.color,
    required this.index,
    required this.start,
    required this.rowTop,
    required this.rowHeight,
    this.opacity = 1,
  });

  final Color color;
  final int index;
  final double start;

  /// Where a row starts, which moves while a section above it opens or
  /// closes.
  final double Function(int index) rowTop;
  final double rowHeight;

  /// Fades the indicator with the section its row closes into.
  final double opacity;

  @override
  State<_SelectionIndicator> createState() => _SelectionIndicatorState();
}

class _SelectionIndicatorState extends State<_SelectionIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _indicatorDuration,
    value: 1,
  );
  late int _from = widget.index;

  @override
  void didUpdateWidget(covariant _SelectionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _from = oldWidget.index;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _topOf(int index) =>
      widget.rowTop(index) + (widget.rowHeight - _indicatorHeight) / 2;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final from = _topOf(_from);
        final to = _topOf(widget.index);
        final lead = Curves.easeOutCubic.transform(math.min(1, t / 0.6));
        final trail = Curves.easeInOutCubic.transform(
          math.max(0, (t - 0.35) / 0.65),
        );
        final (top, bottom) = to >= from
            ? (lerpDouble(from, to, trail)!, lerpDouble(from, to, lead)!)
            : (lerpDouble(from, to, lead)!, lerpDouble(from, to, trail)!);
        return PositionedDirectional(
          start: widget.start,
          top: top,
          width: _indicatorWidth,
          height: bottom - top + _indicatorHeight,
          child: child!,
        );
      },
      child: IgnorePointer(
        child: Opacity(
          opacity: widget.opacity.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: widget.color,
              shape: AppShape.full,
            ),
          ),
        ),
      ),
    );
  }
}
