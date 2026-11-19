import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets(
    'static empty slots reserve lines without animating or clipping',
    (tester) async {
      Future<void> show(String description, {double scale = 1}) async {
        await tester.pumpWidget(
          TestApp(
            child: MediaQuery(
              data: MediaQueryData(
                size: const Size(800, 600),
                textScaler: TextScaler.linear(scale),
              ),
              child: NullStatus(
                key: ValueKey(description),
                illustration: Illustration.search,
                animate: false,
                descriptionMinLines: 2,
                label: 'Empty',
                description: description,
                action: const SizedBox(width: 100, height: 40),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await show('One line');
      final illustration = tester.getRect(find.byType(EmptyIllustration));
      final title = tester.getRect(find.text('Empty'));
      final oneLine = tester.getRect(find.text('One line'));
      expect(oneLine.height, 40);
      expect(oneLine.top - title.bottom, 8);
      expect(tester.binding.transientCallbackCount, 0);

      await show('First\nsecond');
      expect(tester.getRect(find.byType(EmptyIllustration)), illustration);
      expect(tester.getRect(find.text('Empty')), title);
      final twoLines = tester.getRect(find.text('First\nsecond'));
      expect(twoLines.top, oneLine.top);
      expect(twoLines.height, oneLine.height);
      expect(twoLines.center.dx, oneLine.center.dx);
      expect(tester.binding.transientCallbackCount, 0);

      await show('First\nsecond\nthird', scale: 2);
      expect(tester.getSize(find.text('First\nsecond\nthird')).height, 120);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'heading anchor matches a bare empty state and scrolls long text',
    (tester) async {
      tester.view.physicalSize = const Size(420, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      Future<void> show({bool trailing = false}) async {
        await tester.pumpWidget(
          TestApp(
            child: NullStatus(
              illustration: Illustration.search,
              animate: false,
              anchorToHeading: trailing,
              label: 'Empty',
              description: trailing
                  ? 'First\nSecond\nThird\nFourth\nFifth'
                  : null,
              action: trailing
                  ? const SizedBox(
                      key: ValueKey('action'),
                      width: 100,
                      height: 40,
                    )
                  : null,
            ),
          ),
        );
        await tester.pump();
      }

      await show();
      final illustration = tester.getCenter(find.byType(EmptyIllustration));
      final title = tester.getRect(find.text('Empty'));
      await show(trailing: true);
      expect(tester.getCenter(find.byType(EmptyIllustration)), illustration);
      expect(tester.getRect(find.text('Empty')), title);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      await tester.ensureVisible(find.byKey(const ValueKey('action')));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.byKey(const ValueKey('action'))).dy,
        lessThanOrEqualTo(300),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
