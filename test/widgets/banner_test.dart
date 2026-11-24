import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/test_app.dart';

void main() {
  final long = List.filled(12, 'Change it under the settings page.').join(' ');

  Future<BannerHostState> pumpHost(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TestApp(child: SizedBox.expand()));
    return tester.state<BannerHostState>(find.byType(BannerHost));
  }

  Future<void> dropIn(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a banner too long to fit links its details', (tester) async {
    final host = await pumpHost(tester);
    var opened = 0;

    host.show(long, level: BannerLevel.error, onDetails: () => opened++);
    await dropIn(tester);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(find.text(long), findsNothing);
  });

  testWidgets('a long banner falls back to its tap for details', (
    tester,
  ) async {
    final host = await pumpHost(tester);
    var tapped = 0;

    host.show(long, onTap: () => tapped++);
    await dropIn(tester);
    await tester.tap(find.text('Details'));

    expect(tapped, 1);
  });

  testWidgets('a banner that fits has no link', (tester) async {
    final host = await pumpHost(tester);

    host.show('Saved.', onDetails: () {});
    await dropIn(tester);

    expect(find.text('Saved.'), findsOneWidget);
    expect(find.text('Details'), findsNothing);
  });

  testWidgets('a long banner with nothing to open has no link', (tester) async {
    final host = await pumpHost(tester);

    host.show(long, level: BannerLevel.error);
    await dropIn(tester);

    expect(find.text(long), findsOneWidget);
    expect(find.text('Details'), findsNothing);
  });

  testWidgets('a short banner with details keeps its level\'s time', (
    tester,
  ) async {
    final host = await pumpHost(tester);

    host.show('Saved.', onDetails: () {});
    await dropIn(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Saved.'), findsNothing);
  });

  testWidgets('a short banner with details gives way to the next', (
    tester,
  ) async {
    final host = await pumpHost(tester);

    host.show('Low.', level: BannerLevel.warning, onDetails: () {});
    await dropIn(tester);
    host.show('Next.');
    await tester.pump(const Duration(milliseconds: 3200));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Low.'), findsNothing);
    expect(find.text('Next.'), findsOneWidget);
  });

  testWidgets('a banner showing its link stays and is not pushed out', (
    tester,
  ) async {
    final host = await pumpHost(tester);

    host.show(long, level: BannerLevel.warning, onDetails: () {});
    await dropIn(tester);
    expect(find.text('Details'), findsOneWidget);
    host.show('Next.');
    for (var i = 0; i < 11; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Next.'), findsNothing);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Details'), findsNothing);
    expect(find.text('Next.'), findsOneWidget);
  });
}
