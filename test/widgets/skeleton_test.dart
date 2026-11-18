import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/test_app.dart';

void main() {
  const style = TextStyle(fontSize: 14, height: 20 / 14);

  Widget line({bool disableAnimations = false}) => TestApp(
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: const Surface(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('203.0.113.7', style: style),
              SkeletonText(width: 104, style: style),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('takes the height of the line it stands in for', (tester) async {
    await tester.pumpWidget(line());

    expect(
      tester.getSize(find.byType(SkeletonText)),
      Size(104, tester.getSize(find.text('203.0.113.7')).height),
    );
  });

  testWidgets('pulses without rebuilding or repainting', (tester) async {
    await tester.pumpWidget(line());
    await tester.pump(const Duration(milliseconds: 100));
    final opacity = tester
        .widget<FadeTransition>(
          find.descendant(
            of: find.byType(SkeletonText),
            matching: find.byType(FadeTransition),
          ),
        )
        .opacity;
    final before = opacity.value;

    var paints = 0;
    var rebuilds = 0;
    debugProfilePaintsEnabled = true;
    debugOnProfilePaint = (_) => paints++;
    debugOnRebuildDirtyWidget = (_, _) => rebuilds++;
    try {
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    } finally {
      debugProfilePaintsEnabled = false;
      debugOnProfilePaint = null;
      debugOnRebuildDirtyWidget = null;
    }

    expect(opacity.value, isNot(before));
    expect(paints, 0);
    expect(rebuilds, 0);
  });

  testWidgets('holds still when animations are turned off', (tester) async {
    await tester.pumpWidget(line(disableAnimations: true));
    await tester.pumpAndSettle();

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('rests after its pulse budget instead of asking for frames '
      'forever', (tester) async {
    await tester.pumpWidget(line());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.hasRunningAnimations, isTrue);
    // The budget ends the cycle it is in, at full opacity, and then holds.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.hasRunningAnimations, isFalse);
    expect(SchedulerBinding.instance.hasScheduledFrame, isFalse);
    final opacity = tester
        .widget<FadeTransition>(
          find.descendant(
            of: find.byType(SkeletonText),
            matching: find.byType(FadeTransition),
          ),
        )
        .opacity;
    expect(opacity.value, closeTo(1, 1e-9));
    // Still at rest after the dependencies change (theme, media query).
    await tester.pumpWidget(line());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('counts its budget only while tickers run, and starts over '
      'when they come back', (tester) async {
    Widget held(bool enabled) =>
        TickerMode(enabled: enabled, child: line());
    // Held still far longer than the budget (the Core down, a card muting it).
    await tester.pumpWidget(held(false));
    await tester.pump(const Duration(seconds: 30));
    expect(tester.hasRunningAnimations, isFalse);
    // A real wait begins: the same bar pulses for a whole budget.
    await tester.pumpWidget(held(true));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(seconds: 9));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.hasRunningAnimations, isFalse);
    // Rested; muted and on again: a fresh budget once more.
    await tester.pumpWidget(held(false));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(held(true));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.hasRunningAnimations, isTrue);
    // Muted half way: nothing is spent while muted, and it starts over.
    await tester.pumpWidget(held(false));
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpWidget(held(true));
    await tester.pump(const Duration(seconds: 9));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('asks for no frames where tickers are off', (tester) async {
    await tester.pumpWidget(TickerMode(enabled: false, child: line()));
    await tester.pump(const Duration(milliseconds: 16));
    expect(SchedulerBinding.instance.hasScheduledFrame, isFalse);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
