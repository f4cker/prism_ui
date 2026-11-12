import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';

Widget _opener({required ValueSetter<BuildContext> onPressed}) {
  return HostApp(
    home: HostScaffold(
      body: Builder(
        builder: (context) {
          return FilledButton(
            onPressed: () => onPressed(context),
            child: const Text('Open sheet'),
          );
        },
      ),
    ),
  );
}

void main() {
  testWidgets('SideSheet paints the given background', (tester) async {
    final controller = SideSheet.createAnimationController(tester);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      HostApp(
        home: HostScaffold(
          body: SideSheet(
            backgroundColor: const Color(0xFFF44336),
            builder: (_) => const Text('Content'),
          ),
        ),
      ),
    );

    final material = tester.widget<Surface>(
      find
          .ancestor(of: find.text('Content'), matching: find.byType(Surface))
          .first,
    );
    expect(material.color, const Color(0xFFF44336));
    expect(controller.duration, const Duration(milliseconds: 300));
    expect(controller.reverseDuration, const Duration(milliseconds: 200));
  });

  testWidgets(
    'modal side sheet animates, returns a value, and uses a barrier',
    (tester) async {
      String? result;

      await tester.pumpWidget(
        _opener(
          onPressed: (context) async {
            result = await showModalSideSheet<String>(
              context: context,
              barrierColor: const Color(0x73000000),
              backgroundColor: const Color(0xFF4CAF50),
              builder: (context) {
                return TextButton(
                  onPressed: () => Navigator.pop(context, 'done'),
                  child: const Text('Close sheet'),
                );
              },
            );
          },
        ),
      );

      await tester.tap(find.text('Open sheet'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SideSheet), findsOneWidget);
      expect(find.byType(AnimatedModalBarrier), findsOneWidget);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close sheet'));
      await tester.pumpAndSettle();

      expect(result, 'done');
      expect(find.byType(SideSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a tap on a transparent barrier dismisses the side sheet', (
    tester,
  ) async {
    var completed = false;

    await tester.pumpWidget(
      HostApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: HostScaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  await showModalSideSheet<void>(
                    context: context,
                    barrierColor: Colors.transparent,
                    builder: (_) =>
                        const SizedBox(width: 200, child: Text('Dismiss me')),
                  );
                  completed = true;
                },
                child: const Text('Open transparent'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open transparent'));
    await tester.pumpAndSettle();
    expect(find.byType(ModalBarrier), findsWidgets);

    await tester.tapAt(const Offset(20, 300));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(find.text('Dismiss me'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a screen reader reaches the barrier beside the side sheet', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _opener(
        onPressed: (context) => showModalSideSheet<void>(
          context: context,
          builder: (_) => const Text('Side'),
        ),
      ),
    );
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    final sheet = tester.getRect(find.byType(SideSheet));
    final barrier = tester.getSemantics(find.bySemanticsLabel('Close')).rect;
    expect(barrier.width, closeTo(sheet.left, 0.1));
    expect(
      barrier.height,
      tester.view.physicalSize.height / tester.view.devicePixelRatio,
    );
    semantics.dispose();
  });
  group('floating side sheet', () {
    Future<void> open(WidgetTester tester, Size view) async {
      tester.view.physicalSize = view;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _opener(
          onPressed: (context) => showModalSideSheet<void>(
            context: context,
            builder: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(child: SizedBox()),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close sheet'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sheet'));
    }

    double opacityOf(WidgetTester tester) => tester
        .widget<Opacity>(
          find.ancestor(
            of: find.byType(SideSheet),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;

    test('insets the panel and narrows it before falling back', () {
      SideSheetGeometry at(double width, double height) =>
          SideSheetGeometry.of(Size(width, height));
      expect((at(1200, 800).width, at(1200, 800).inset), (480, 12));
      expect((at(800, 400).width, at(800, 400).inset), (360, 8));
      expect((at(600, 800).width, at(600, 800).inset), (360, 12));
      expect(at(439, 800).floating, isFalse);
      expect(at(439, 800).width, 360);
    });

    testWidgets('floats off the edges, slides 24 in and fades in 200ms', (
      tester,
    ) async {
      await open(tester, const Size(800, 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final moving = tester.getRect(find.byType(SideSheet));
      expect(moving.left, greaterThan(428));
      expect(moving.left, lessThan(428 + 24));
      expect(opacityOf(tester), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester.getRect(find.byType(SideSheet)),
        const Rect.fromLTWH(428, 12, 360, 576),
      );
      expect(opacityOf(tester), 1);
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(SideSheet),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as ShapeDecoration;
      expect(decoration.shape, AppShape.xl);
      expect(decoration.shadows, hasLength(2));

      await tester.tap(find.text('Close sheet'));
      await tester.pump();
      final route = ModalRoute.of(tester.element(find.text('Close sheet')))!;
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 160),
      );
      await tester.pump(const Duration(milliseconds: 160));
      expect(route.animation!.value, 0);
      await tester.pumpAndSettle();
      expect(find.byType(SideSheet), findsNothing);
    });

    testWidgets('only fades when motion is reduced', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await open(tester, const Size(800, 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getRect(find.byType(SideSheet)).left, 428);
      expect(opacityOf(tester), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 80));
      expect(opacityOf(tester), 1);
    });

    testWidgets('a short view keeps 8 around and the footer in view', (
      tester,
    ) async {
      await open(tester, const Size(800, 400));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(SideSheet)),
        const Rect.fromLTWH(432, 8, 360, 384),
      );
      final close = tester.getRect(find.text('Close sheet'));
      expect(close.bottom, lessThanOrEqualTo(392));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a view too narrow to float keeps the flush sheet', (
      tester,
    ) async {
      await open(tester, const Size(430, 600));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(SideSheet)),
        const Rect.fromLTWH(70, 0, 360, 600),
      );
      expect(
        find.descendant(
          of: find.byType(SideSheet),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Close sheet'));
      await tester.pumpAndSettle();
      expect(find.byType(SideSheet), findsNothing);
    });
  });
}
