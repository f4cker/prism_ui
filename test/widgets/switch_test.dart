import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/test_app.dart';

void main() {
  Finder fadeOf() =>
      find.descendant(of: find.byType(Switch), matching: find.byType(Opacity));

  testWidgets('a disabled switch keeps the M3 look unless asked to fade', (
    tester,
  ) async {
    await tester.pumpWidget(
      const TestApp(
        child: Center(child: Switch(value: false, onChanged: null)),
      ),
    );
    expect(fadeOf(), findsNothing);

    await tester.pumpWidget(
      const TestApp(
        child: Center(
          child: Switch(value: false, onChanged: null, fadeWhenDisabled: true),
        ),
      ),
    );
    expect(tester.widget<Opacity>(fadeOf()).opacity, 0.45);
  });

  testWidgets('an enabled switch never fades', (tester) async {
    await tester.pumpWidget(
      TestApp(
        child: Center(
          child: Switch(value: true, onChanged: (_) {}, fadeWhenDisabled: true),
        ),
      ),
    );
    expect(fadeOf(), findsNothing);
  });
}
