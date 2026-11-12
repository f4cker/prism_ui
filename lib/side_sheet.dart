import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/l10n.dart';
import 'package:prism_ui/color.dart';
import 'package:prism_ui/drag_back.dart';
import 'package:prism_ui/shape.dart';
import 'package:prism_ui/sheet_navigator.dart';
import 'package:prism_ui/surface.dart';
import 'package:prism_ui/theme_data.dart';

const Duration _sideSheetEnterDuration = Duration(milliseconds: 300);
const Duration _sideSheetExitDuration = Duration(milliseconds: 200);
const Curve _sideSheetCurve = Easing.standardDecelerate;

const double _minWidth = 360;
const double _maxWidth = 560;
const double _widthFactor = 0.4;

double _widthFor(double viewWidth) {
  return (viewWidth * _widthFactor).clamp(_minWidth, _maxWidth);
}

const Duration _floatingEnterDuration = Duration(milliseconds: 200);
const Duration _floatingExitDuration = Duration(milliseconds: 160);
const Duration _reducedMotionDuration = Duration(milliseconds: 120);
const double _floatingInset = 12;
const double _floatingInsetShort = 8;
const double _shortViewHeight = 480;
const double _pageLeftVisible = 320;
const double _narrowPageMargin = 56;
const double _floatingSlide = 24;

/// Where the sheet sits in a view: a panel floating [inset] off the top,
/// trailing and bottom edges, or flush with them when the view is too narrow
/// to leave a page beside a floating panel at least [_minWidth] wide.
@immutable
class SideSheetGeometry {
  const SideSheetGeometry._({required this.width, required this.inset});

  factory SideSheetGeometry.of(Size view) {
    final width = _widthFor(view.width);
    final inset = view.height < _shortViewHeight
        ? _floatingInsetShort
        : _floatingInset;
    if (view.width >= width + inset * 2 + _pageLeftVisible) {
      return SideSheetGeometry._(width: width, inset: inset);
    }
    final narrowed = math.min(
      width,
      view.width - inset * 2 - _narrowPageMargin,
    );
    if (narrowed < _minWidth) {
      return SideSheetGeometry._(width: width, inset: 0);
    }
    return SideSheetGeometry._(width: narrowed, inset: inset);
  }

  final double width;
  final double inset;

  bool get floating => inset > 0;
}

List<BoxShadow> _floatingShadows(Brightness brightness) => switch (brightness) {
  Brightness.light => const [
    BoxShadow(color: Color(0x24000000), blurRadius: 32, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
  ],
  Brightness.dark => const [
    BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, 8)),
  ],
};

class SideSheet extends StatefulWidget {
  const SideSheet({
    super.key,
    this.backgroundColor,
    this.floating = false,
    required this.builder,
  });

  final WidgetBuilder builder;

  final Color? backgroundColor;

  /// Rounds every corner and casts a shadow, for a panel off the view's edges.
  final bool floating;

  @override
  State<SideSheet> createState() => _SideSheetState();

  static AnimationController createAnimationController(TickerProvider vsync) {
    return AnimationController(
      duration: _sideSheetEnterDuration,
      reverseDuration: _sideSheetExitDuration,
      debugLabel: 'SideSheet',
      vsync: vsync,
    );
  }
}

class _SideSheetState extends State<SideSheet> {
  final GlobalKey _childKey = GlobalKey(debugLabel: 'SideSheet child');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shape = widget.floating ? AppShape.xl : AppShape.none;
    final surface = Surface(
      key: _childKey,
      color: widget.backgroundColor ?? SurfaceLevel.page.colorOf(colorScheme),
      shape: shape,
      clipBehavior: widget.floating ? Clip.antiAlias : Clip.none,
      child: widget.builder(context),
    );
    if (!widget.floating) {
      return surface;
    }
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: _floatingShadows(colorScheme.brightness),
      ),
      child: surface,
    );
  }
}

typedef _SizeChangeCallback<Size> = void Function(Size);

class _SideSheetLayoutWithSizeListener extends SingleChildRenderObjectWidget {
  const _SideSheetLayoutWithSizeListener({
    required this.onChildSizeChanged,
    required this.shift,
    required this.inset,
    required this.width,
    super.child,
  });

  final _SizeChangeCallback<Size> onChildSizeChanged;
  final double shift;
  final double inset;
  final double width;

  @override
  _RenderSideSheetLayoutWithSizeListener createRenderObject(
    BuildContext context,
  ) {
    return _RenderSideSheetLayoutWithSizeListener(
      onChildSizeChanged: onChildSizeChanged,
      shift: shift,
      inset: inset,
      width: width,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSideSheetLayoutWithSizeListener renderObject,
  ) {
    renderObject.onChildSizeChanged = onChildSizeChanged;
    renderObject.shift = shift;
    renderObject.inset = inset;
    renderObject.width = width;
  }
}

class _RenderSideSheetLayoutWithSizeListener extends RenderShiftedBox {
  _RenderSideSheetLayoutWithSizeListener({
    RenderBox? child,
    required _SizeChangeCallback<Size> onChildSizeChanged,
    required double shift,
    required double inset,
    required double width,
  }) : _onChildSizeChanged = onChildSizeChanged,
       _shift = shift,
       _inset = inset,
       _width = width,
       super(child);

  Size _lastSize = Size.zero;

  _SizeChangeCallback<Size> get onChildSizeChanged => _onChildSizeChanged;
  _SizeChangeCallback<Size> _onChildSizeChanged;

  set onChildSizeChanged(_SizeChangeCallback<Size> newCallback) {
    if (_onChildSizeChanged == newCallback) {
      return;
    }

    _onChildSizeChanged = newCallback;
    markNeedsLayout();
  }

  /// How far right of its resting place the sheet is drawn.
  double get shift => _shift;
  double _shift;

  set shift(double newValue) {
    if (_shift == newValue) {
      return;
    }

    _shift = newValue;
    markNeedsLayout();
  }

  double get inset => _inset;
  double _inset;

  set inset(double newValue) {
    if (_inset == newValue) {
      return;
    }

    _inset = newValue;
    markNeedsLayout();
  }

  double get width => _width;
  double _width;

  set width(double newValue) {
    if (_width == newValue) {
      return;
    }

    _width = newValue;
    markNeedsLayout();
  }

  Size _getSize(BoxConstraints constraints) {
    return constraints.constrain(constraints.biggest);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final double width = _getSize(
      BoxConstraints.tightForFinite(height: height),
    ).width;
    if (width.isFinite) {
      return width;
    }
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final double width = _getSize(
      BoxConstraints.tightForFinite(height: height),
    ).width;
    if (width.isFinite) {
      return width;
    }
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final double height = _getSize(
      BoxConstraints.tightForFinite(width: width),
    ).height;
    if (height.isFinite) {
      return height;
    }
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final double height = _getSize(
      BoxConstraints.tightForFinite(width: width),
    ).height;
    if (height.isFinite) {
      return height;
    }
    return 0.0;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _getSize(constraints);
  }

  BoxConstraints _getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.tightFor(
      width: math.min(width, constraints.maxWidth - inset * 2),
      height: math.max(constraints.maxHeight - inset * 2, 0),
    );
  }

  Offset _getPositionForChild(Size size, Size childSize) {
    return Offset(size.width - inset - childSize.width + shift, inset);
  }

  @override
  void performLayout() {
    size = _getSize(constraints);
    if (child != null) {
      final BoxConstraints childConstraints = _getConstraintsForChild(
        constraints,
      );
      assert(childConstraints.debugAssertIsValid(isAppliedConstraint: true));
      child!.layout(
        childConstraints,
        parentUsesSize: !childConstraints.isTight,
      );
      final BoxParentData childParentData = child!.parentData! as BoxParentData;
      childParentData.offset = _getPositionForChild(
        size,
        childConstraints.isTight ? childConstraints.smallest : child!.size,
      );
      final Size childSize = childConstraints.isTight
          ? childConstraints.smallest
          : child!.size;

      if (_lastSize != childSize) {
        _lastSize = childSize;
        _onChildSizeChanged.call(_lastSize);
      }
    }
  }
}

class _ModalSideSheet<T> extends StatefulWidget {
  const _ModalSideSheet({super.key, required this.route, this.backgroundColor});

  final ModalSideSheetRoute<T> route;
  final Color? backgroundColor;

  @override
  _ModalSideSheetState<T> createState() => _ModalSideSheetState<T>();
}

class _ModalSideSheetState<T> extends State<_ModalSideSheet<T>> {
  late final CurvedAnimation _floatingCurve = CurvedAnimation(
    parent: widget.route.animation!,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void dispose() {
    _floatingCurve.dispose();
    super.dispose();
  }

  String _getRouteLabel(UiLocalizations localizations) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return '';
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return localizations.dialog;
    }
  }

  EdgeInsets _getNewClipDetails(Size topLayerSize, double inset) {
    return EdgeInsets.fromLTRB(0, 0, topLayerSize.width + inset, 0);
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    final localizations = UiLocalizations.of(context);
    final String routeLabel = _getRouteLabel(localizations);
    final geometry = SideSheetGeometry.of(MediaQuery.sizeOf(context));
    final width = geometry.width;
    final inset = geometry.inset;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final route = widget.route;
    return AnimatedBuilder(
      animation: route.animation!,
      child: route.dragBackDetector(
        SideSheet(
          builder: route.builder,
          backgroundColor: widget.backgroundColor,
          floating: geometry.floating,
        ),
      ),
      builder: (BuildContext context, Widget? child) {
        final value = route.animation!.value;
        var shift = 0.0;
        var opacity = 1.0;
        if (route.isDragBackActive) {
          shift = (width + inset) * (1 - value);
        } else if (!geometry.floating) {
          shift = width * (1 - _sideSheetCurve.transform(value));
        } else {
          opacity = _floatingCurve.value;
          if (!reduceMotion) {
            shift = _floatingSlide * (1 - opacity);
          }
        }
        return Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: routeLabel,
          explicitChildNodes: true,
          child: ClipRect(
            child: _SideSheetLayoutWithSizeListener(
              onChildSizeChanged: (Size size) {
                widget.route._didChangeBarrierSemanticsClip(
                  _getNewClipDetails(size, inset),
                );
              },
              shift: shift,
              inset: inset,
              width: width,
              child: Opacity(opacity: opacity, child: child),
            ),
          ),
        );
      },
    );
  }
}

class ModalSideSheetRoute<T> extends PopupRoute<T>
    with DragBackRouteMixin<T>, SheetCoverRouteMixin<T> {
  ModalSideSheetRoute({
    required this.builder,
    this.barrierLabel,
    this.barrierOnTapHint,
    this.backgroundColor,
    this.modalBarrierColor,
  });

  final WidgetBuilder builder;

  final Color? backgroundColor;

  final Color? modalBarrierColor;

  final String? barrierOnTapHint;

  final ValueNotifier<EdgeInsets> _clipDetailsNotifier =
      ValueNotifier<EdgeInsets>(EdgeInsets.zero);

  @override
  void dispose() {
    _clipDetailsNotifier.dispose();
    super.dispose();
  }

  bool _didChangeBarrierSemanticsClip(EdgeInsets newClipDetails) {
    if (_clipDetailsNotifier.value == newClipDetails) {
      return false;
    }
    _clipDetailsNotifier.value = newClipDetails;
    return true;
  }

  @override
  Duration get transitionDuration => _durations.enter;

  @override
  Duration get reverseTransitionDuration => _durations.exit;

  /// A floating panel's motion is shorter, and only a fade when the platform
  /// asks for reduced motion; a flush sheet keeps its slide.
  ({Duration enter, Duration exit}) get _durations {
    final context = navigator?.context;
    final view = context == null ? null : MediaQuery.maybeOf(context);
    if (view == null || !SideSheetGeometry.of(view.size).floating) {
      return (enter: _sideSheetEnterDuration, exit: _sideSheetExitDuration);
    }
    if (view.disableAnimations) {
      return (enter: _reducedMotionDuration, exit: _reducedMotionDuration);
    }
    return (enter: _floatingEnterDuration, exit: _floatingExitDuration);
  }

  @override
  bool get barrierDismissible => true;

  @override
  final String? barrierLabel;

  @override
  Color get barrierColor => modalBarrierColor ?? Colors.black54;

  @override
  AnimationController createAnimationController() {
    final durations = _durations;
    return AnimationController(
      duration: durations.enter,
      reverseDuration: durations.exit,
      debugLabel: 'SideSheet',
      vsync: navigator!,
      animationBehavior: AnimationBehavior.preserve,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final Widget content = DisplayFeatureSubScreen(
      child: Builder(
        builder: (BuildContext context) {
          final colorScheme = Theme.of(context).colorScheme;
          return _ModalSideSheet<T>(
            route: this,
            backgroundColor:
                backgroundColor ?? SurfaceLevel.page.colorOf(colorScheme),
          );
        },
      ),
    );

    return ElevatedSurfaceTheme(child: content);
  }

  @override
  Widget buildModalBarrier() {
    if (barrierColor.a != 0 && !offstage) {
      assert(barrierColor != barrierColor.opacity0);
      final Animation<Color?> color = animation!.drive(
        ColorTween(
          begin: barrierColor.opacity0,
          end: barrierColor,
        ).chain(CurveTween(curve: barrierCurve)),
      );
      return AnimatedModalBarrier(
        color: color,
        dismissible: barrierDismissible,
        semanticsLabel: barrierLabel,
        barrierSemanticsDismissible: semanticsDismissible,
        clipDetailsNotifier: _clipDetailsNotifier,
        semanticsOnTapHint: barrierOnTapHint,
      );
    } else {
      return ModalBarrier(
        dismissible: barrierDismissible,
        semanticsLabel: barrierLabel,
        barrierSemanticsDismissible: semanticsDismissible,
        clipDetailsNotifier: _clipDetailsNotifier,
        semanticsOnTapHint: barrierOnTapHint,
      );
    }
  }
}

Future<T?> showModalSideSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  Color? barrierColor,
}) {
  assert(debugCheckHasMediaQuery(context));

  final navigator = sheetNavigatorOf(context);
  final localizations = UiLocalizations.of(context);
  return navigator.push(
    ModalSideSheetRoute<T>(
      builder: builder,
      barrierLabel: localizations.close,
      barrierOnTapHint: localizations.close,
      backgroundColor: backgroundColor,
      modalBarrierColor: barrierColor,
    ),
  );
}
