import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:prism_ui/context.dart';
import 'package:prism_ui/shape.dart';

/// A pulsing bar that holds the place of one line of [style] text.
class SkeletonText extends StatelessWidget {
  const SkeletonText({super.key, required this.width, this.style});

  final double width;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(this.style);
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        child: Stack(
          children: [
            Text(' ', style: style),
            Positioned.fill(
              child: Center(
                child: SkeletonPill(
                  width: double.infinity,
                  height: MediaQuery.textScalerOf(
                    context,
                  ).scale(style.fontSize ?? 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pulsing pill that holds the place of a block of a known size.
class SkeletonPill extends StatefulWidget {
  const SkeletonPill({super.key, required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<SkeletonPill> createState() => _SkeletonPillState();
}

class _SkeletonPillState extends State<SkeletonPill>
    with SingleTickerProviderStateMixin {
  static const _period = Duration(milliseconds: 1600);

  /// How long a bar pulses while its tickers run before it rests: a
  /// placeholder that has waited this long is not about to be replaced, and
  /// each pulse frame redraws the window (and what a glass pane captures
  /// behind it). The budget counts only while [TickerMode] is on (not while a
  /// page is off screen, the app hidden or a card holds it still), and starts
  /// over whenever tickers come back on: a wait that really begins then pulses
  /// again.
  static const pulseBudget = Duration(seconds: 10);

  late final AnimationController _controller;
  late final Animation<double> _opacity = _controller.drive(const _Pulse());
  Timer? _budget;
  var _resting = false;
  bool? _ticking;

  // Starting from the wall clock keeps bars that appear at different times
  // pulsing in step.
  static double get _phase =>
      DateTime.now().millisecondsSinceEpoch %
      _period.inMilliseconds /
      _period.inMilliseconds;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _period,
      value: _phase,
    );
  }

  /// Ends the pulse at full opacity (the end of a cycle), then holds still.
  void _rest() {
    _budget = null;
    if (!mounted || _resting) {
      return;
    }
    _resting = true;
    if (!_controller.isAnimating) {
      _controller.value = 1;
      return;
    }
    final left = (1 - _controller.value) * _period.inMicroseconds;
    _controller.animateTo(1, duration: Duration(microseconds: left.round()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ticking = TickerMode.valuesOf(context).enabled;
    if (ticking != _ticking) {
      _ticking = ticking;
      _budget?.cancel();
      _budget = null;
      if (ticking) {
        // A fresh budget each time tickers come back on.
        if (_resting) {
          _resting = false;
          _controller.value = _phase;
        }
        _budget = Timer(pulseBudget, _rest);
      }
    }
    if (_resting) {
      return;
    }
    if (context.disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _budget?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bar = DecoratedBox(
      decoration: ShapeDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        shape: AppShape.full,
      ),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: context.disableAnimations
            ? bar
            : FadeTransition(opacity: _opacity, child: bar),
      ),
    );
  }
}

class _Pulse extends Animatable<double> {
  const _Pulse();

  @override
  double transform(double t) => 0.75 + 0.25 * math.cos(2 * math.pi * t);
}
