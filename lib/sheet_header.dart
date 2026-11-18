import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/context.dart';
import 'package:prism_ui/metrics.dart';
import 'package:prism_ui/scroll_behavior.dart';
import 'package:prism_ui/shape.dart';

import 'inherited.dart';
import 'sheet_navigator.dart';
import 'package:prism_ui/surface.dart';

class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  static const height = _topPadding + _thickness;

  static const _topPadding = 6.0;
  static const _thickness = 4.0;
  static const _width = 28.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: _topPadding),
      child: Container(
        alignment: Alignment.center,
        height: _thickness,
        width: _width,
        decoration: ShapeDecoration(
          color: context.colorScheme.onSurfaceVariant,
          shape: AppShape.all(_thickness / 2),
        ),
      ),
    );
  }
}

/// A drag handle, or its space, over [appBar], together exactly
/// [sheetAppBarHeight] tall.
class SheetToolBar extends StatelessWidget {
  const SheetToolBar({super.key, required this.appBar, this.dragHandle = true});

  static const _trailing =
      sheetAppBarHeight - SheetDragHandle.height - sheetToolbarHeight;

  final Widget appBar;
  final bool dragHandle;

  @override
  Widget build(BuildContext context) {
    final bar = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A paged sheet holds its handle still over the pages it moves.
        dragHandle && !isSheetPage(context)
            ? const SheetDragHandle()
            : const SizedBox(height: SheetDragHandle.height),
        appBar,
        const SizedBox(height: _trailing),
      ],
    );
    return dragHandle
        ? GestureDetector(behavior: HitTestBehavior.opaque, child: bar)
        : bar;
  }
}

/// Fades the surface behind [child] toward its foot so content reads through,
/// easing out over [overhang] past the foot so the fade shows no edge.
///
/// With a [blurSigma], what is behind is also blurred: at [blurSigma] over
/// the header, then in three steps (0.6, 0.3 and 0.1 of it) over the
/// [overhang]. Flutter cannot fade a backdrop blur by a mask (under a
/// ShaderMask the filter reads an empty layer and blurs nothing), so it
/// steps down under the colour's smooth fade.
///
/// With an [overhangPresence], the overhang's blur and colour are scaled by
/// its value (0 to 1): at 0 the overhang covers nothing.
class FloatingHeader extends StatelessWidget {
  const FloatingHeader({
    super.key,
    required this.backgroundColor,
    this.fadeStart = 0.5,
    this.overhang = 0,
    this.alpha = _alpha,
    this.blurSigma = 0,
    this.overhangPresence,
    required this.child,
  }) : assert(overhangPresence == null || fadeStart == 1);

  static const _alpha = 0.9;
  static const _fadeSteps = 8;
  static const _overhangSigmas = [0.6, 0.3, 0.1];

  final Color backgroundColor;
  final double fadeStart;
  final double overhang;

  /// The colour's opacity above the fade.
  final double alpha;
  final double blurSigma;

  /// How much of the overhang shows, from 0 to 1; null for all of it. Only
  /// with a [fadeStart] of 1, where the fade lies wholly in the overhang.
  final ValueListenable<double>? overhangPresence;
  final Widget child;

  Gradient _scrimOf(double height, double presence) {
    final start = (height - overhang) * fadeStart / height;
    final stops = <double>[0];
    final colors = <Color>[backgroundColor.withValues(alpha: alpha)];
    if (presence < 1) {
      stops.add(start);
      colors.add(backgroundColor.withValues(alpha: alpha));
    }
    for (var i = 0; i <= _fadeSteps; i++) {
      final t = i / _fadeSteps;
      stops.add(start + (1 - start) * t);
      colors.add(
        backgroundColor.withValues(
          alpha: alpha * presence * (1 - Curves.easeInOut.transform(t)),
        ),
      );
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: stops,
      colors: colors,
    );
  }

  // Bounded: a blur reads only what is under its own box. Unbounded, a list
  // resting just below the bar would shade its foot before anything had
  // scrolled under it.
  static Widget _blur(double sigma) => sigma < 0.01
      ? const SizedBox.expand()
      : ClipRect(
          child: BackdropFilter(
            filterConfig: ImageFilterConfig.blur(
              sigmaX: sigma,
              sigmaY: sigma,
              bounded: true,
            ),
            child: const SizedBox.expand(),
          ),
        );

  Widget _surface(double presence) {
    final scrim = LayoutBuilder(
      builder: (_, constraints) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: _scrimOf(constraints.maxHeight, presence),
        ),
      ),
    );
    if (blurSigma <= 0) return scrim;
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            Expanded(child: _blur(blurSigma)),
            if (overhang > 0)
              for (final step in _overhangSigmas)
                SizedBox(
                  height: overhang / _overhangSigmas.length,
                  child: _blur(blurSigma * step * presence),
                ),
          ],
        ),
        scrim,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final presence = overhangPresence;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: -overhang,
          child: IgnorePointer(
            child: presence == null || overhang <= 0
                ? _surface(1)
                : ValueListenableBuilder(
                    valueListenable: presence,
                    builder: (_, value, _) =>
                        _surface(clampDouble(value, 0, 1)),
                  ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Floats [header] over [body], fading it out so content reads through it
/// as it scrolls past; [footer] sits on its own surface.
class FloatingHeaderBody extends StatelessWidget {
  const FloatingHeaderBody({
    super.key,
    required this.backgroundColor,
    required this.header,
    required this.body,
    this.footer,
  });

  final Color backgroundColor;
  final Widget header;
  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ScrollConfiguration(
          behavior: const ShowBarScrollBehavior(),
          child: body,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: FloatingHeader(
            backgroundColor: backgroundColor,
            child: header,
          ),
        ),
        if (footer != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SheetOverhangLift(
              child: Surface.transparent(child: footer!),
            ),
          ),
      ],
    );
  }
}

/// Holds its child clear of the part of the sheet that hangs below the screen
/// while the sheet is dragged below its shortest detent.
class SheetOverhangLift extends SingleChildRenderObjectWidget {
  const SheetOverhangLift({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSheetOverhangLift(overhang: SheetOverhangScope.of(context));
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderSheetOverhangLift).overhang = SheetOverhangScope.of(
      context,
    );
  }
}

class _RenderSheetOverhangLift extends RenderTransform {
  _RenderSheetOverhangLift({required ValueListenable<double>? overhang})
    : _overhang = overhang,
      super(transform: Matrix4.identity(), transformHitTests: true) {
    _overhang?.addListener(_syncTransform);
  }

  ValueListenable<double>? _overhang;

  set overhang(ValueListenable<double>? value) {
    if (_overhang == value) {
      return;
    }
    _overhang?.removeListener(_syncTransform);
    _overhang = value;
    _overhang?.addListener(_syncTransform);
    _syncTransform();
  }

  @override
  void performLayout() {
    super.performLayout();
    _syncTransform();
  }

  @override
  void dispose() {
    _overhang?.removeListener(_syncTransform);
    super.dispose();
  }

  void _syncTransform() {
    transform = Matrix4.translationValues(0, -(_overhang?.value ?? 0), 0);
  }
}
