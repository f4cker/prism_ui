import 'package:prism_ui/icons/icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/host_scaffold.dart';

final _paneFinder = find
    .byWidgetPredicate((widget) => widget is Surface && widget.elevation > 0)
    .first;

const _destinations = [
  SidebarDestination(glyph: Glyphs.pin, label: 'Dashboard'),
  SidebarDestination(glyph: Glyphs.search, label: 'Proxies'),
  SidebarDestination(glyph: Glyphs.sort, label: 'Profiles'),
];

Finder _glyph(Glyph glyph) => find.byWidgetPredicate(
  (widget) => widget is AnimatedGlyph && widget.glyph == glyph,
);

double _fillOf(WidgetTester tester, Glyph glyph) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: _glyph(glyph), matching: find.byType(CustomPaint)),
  );
  return (paint.painter! as GlyphPainter).fill;
}

Widget _sidebar({
  List<SidebarDestination> destinations = _destinations,
  int selectedIndex = 0,
  bool expanded = true,
  ValueChanged<int>? onSelected,
  VoidCallback? onToggle,
  Size windowControls = Size.zero,
  EdgeInsets safePadding = EdgeInsets.zero,
}) {
  return TestApp(
    child: HostScaffold(
      body: Row(
        children: [
          SizedBox(
            height: 400,
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(padding: safePadding),
                child: NavigationSidebar(
                  destinations: destinations,
                  selectedIndex: selectedIndex,
                  expanded: expanded,
                  onSelected: onSelected ?? (_) {},
                  onToggle: onToggle,
                  windowControls: windowControls,
                ),
              ),
            ),
          ),
          const Expanded(child: SizedBox.expand(key: ValueKey('content'))),
        ],
      ),
    ),
  );
}

Finder get _sidebarFinder => find.byType(NavigationSidebar);

Finder _indicator(WidgetTester tester) {
  final primary = Theme.of(tester.element(_sidebarFinder)).colorScheme.primary;
  return find.byWidgetPredicate(
    (widget) =>
        widget is DecoratedBox &&
        widget.decoration is ShapeDecoration &&
        (widget.decoration as ShapeDecoration).color == primary,
  );
}

Finder _labels(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate(
    (widget) => widget is Opacity && widget.alwaysIncludeSemantics,
  ),
);

Iterable<double> _labelOpacities(WidgetTester tester, String label) {
  return tester.widgetList<Opacity>(_labels(label)).map((o) => o.opacity);
}

Finder _shown(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) =>
        widget is Opacity &&
        widget.alwaysIncludeSemantics &&
        widget.opacity == 1,
  ),
  matching: find.text(label),
);

Finder _rowTooltip(String message) => find.byWidgetPredicate(
  (widget) => widget is Tooltip && widget.message == message,
);

void main() {
  testWidgets('the selected row carries a centered indicator', (tester) async {
    await tester.pumpWidget(_sidebar(selectedIndex: 1));

    final indicator = tester.getRect(_indicator(tester));
    expect(indicator.width, 3);
    expect(indicator.height, 16);
    expect(
      indicator.center.dy,
      moreOrLessEquals(tester.getCenter(_glyph(Glyphs.search)).dy),
    );
    expect(tester.getSize(_sidebarFinder).width, 220);
    expect(_labelOpacities(tester, 'Proxies'), [1]);
    expect(
      tester.getSemantics(find.text('Proxies')),
      isSemantics(isSelected: true, isButton: true),
    );
  });

  testWidgets('the indicator stretches toward the new row and settles on it', (
    tester,
  ) async {
    await tester.pumpWidget(_sidebar());
    final start = tester.getRect(_indicator(tester));

    await tester.pumpWidget(_sidebar(selectedIndex: 2));
    await tester.pump(const Duration(milliseconds: 160));
    final middle = tester.getRect(_indicator(tester));
    expect(middle.top, greaterThanOrEqualTo(start.top));
    expect(middle.height, greaterThan(16));

    await tester.pumpAndSettle();
    final end = tester.getRect(_indicator(tester));
    expect(end.height, 16);
    expect(
      end.center.dy,
      moreOrLessEquals(tester.getCenter(_glyph(Glyphs.sort)).dy),
    );
  });

  testWidgets('only the selected row fills its icon', (tester) async {
    await tester.pumpWidget(_sidebar());
    expect(_fillOf(tester, Glyphs.pin), 1);
    expect(_fillOf(tester, Glyphs.sort), 0);

    await tester.pumpWidget(_sidebar(selectedIndex: 2));
    await tester.pumpAndSettle();
    expect(_fillOf(tester, Glyphs.pin), 0);
    expect(_fillOf(tester, Glyphs.sort), 1);
  });

  testWidgets('the toggle widens the sidebar in place when it can', (
    tester,
  ) async {
    var toggled = 0;
    int? selected;
    await tester.pumpWidget(
      _sidebar(
        expanded: false,
        onToggle: () => toggled++,
        onSelected: (index) => selected = index,
      ),
    );

    expect(tester.getSize(_sidebarFinder).width, 48);
    expect(_labelOpacities(tester, 'Proxies'), [0]);
    expect(_rowTooltip('Proxies'), findsOneWidget);
    await tester.tap(_glyph(Glyphs.sort));
    expect(selected, 2);

    await tester.tap(find.byTooltip('Expand'));
    await tester.pump();
    expect(toggled, 1);
    expect(find.text('Proxies'), findsOneWidget);

    await tester.pumpWidget(_sidebar(onToggle: () {}));
    await tester.pump(const Duration(milliseconds: 120));
    final width = tester.getSize(_sidebarFinder).width;
    expect(width, allOf(greaterThan(48), lessThan(220)));
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(tester.getSize(_sidebarFinder).width, 220);
    expect(_rowTooltip('Proxies'), findsNothing);
    expect(find.byTooltip('Collapse'), findsOneWidget);
  });

  testWidgets('an expanded row whose label is cut off keeps its tooltip', (
    tester,
  ) async {
    const long = 'Подключения и активные соединения';
    await tester.pumpWidget(
      _sidebar(
        destinations: const [
          ..._destinations,
          SidebarDestination(glyph: Glyphs.copy, label: long),
        ],
        onToggle: () {},
      ),
    );

    expect(_rowTooltip(long), findsOneWidget);
    expect(_rowTooltip('Proxies'), findsNothing);
  });

  testWidgets('the toggle glyph follows the pane as it widens', (tester) async {
    List<Rect> glyph(String tooltip) => [
      for (final shape
          in tester
              .widget<GlyphIcon>(
                find.descendant(
                  of: find.byTooltip(tooltip),
                  matching: find.byType(GlyphIcon),
                ),
              )
              .glyph
              .shapes)
        shape.path.getBounds(),
    ];

    await tester.pumpWidget(_sidebar(expanded: false, onToggle: () {}));
    final collapsed = glyph('Expand');

    await tester.pumpWidget(_sidebar(onToggle: () {}));
    await tester.pump(const Duration(milliseconds: 120));
    final midway = glyph('Collapse');
    expect(midway, isNot(collapsed));

    await tester.pumpAndSettle();
    expect(glyph('Collapse'), isNot(midway));
  });

  testWidgets('window controls keep their corner clear', (tester) async {
    await tester.pumpWidget(
      _sidebar(
        expanded: false,
        onToggle: () {},
        windowControls: const Size(78, 32),
      ),
    );

    final sidebar = tester.getRect(_sidebarFinder);
    expect(sidebar.width, 78);
    final toggle = find.byTooltip('Expand');
    expect(
      tester.getTopLeft(toggle).dy,
      greaterThanOrEqualTo(sidebar.top + 32),
    );
    expect(tester.getCenter(toggle).dx, sidebar.center.dx);
    expect(tester.getCenter(_glyph(Glyphs.sort)).dx, sidebar.center.dx);
    final selectedItem = tester.getRect(
      find
          .ancestor(of: _glyph(Glyphs.pin), matching: find.byType(PressRegion))
          .first,
    );
    expect(selectedItem.size, const Size(54, 40));
    expect(selectedItem.center.dx, sidebar.center.dx);

    final folder = tester.getCenter(_glyph(Glyphs.sort));
    await tester.pumpWidget(
      _sidebar(onToggle: () {}, windowControls: const Size(78, 32)),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(_sidebarFinder).width, 220);
    expect(tester.getCenter(_glyph(Glyphs.sort)), folder);
  });

  group('without room to widen', () {
    Future<void> openOverlay(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Expand'));
      await tester.pumpAndSettle();
      expect(find.text('Proxies'), findsNWidgets(2));
    }

    testWidgets('the toggle opens the pane over the content', (tester) async {
      await tester.pumpWidget(_sidebar(expanded: false));
      final contentWidth = tester
          .getSize(find.byKey(const ValueKey('content')))
          .width;

      await openOverlay(tester);

      expect(tester.getSize(_sidebarFinder).width, 48);
      expect(
        tester.getSize(find.byKey(const ValueKey('content'))).width,
        contentWidth,
      );
      expect(_labelOpacities(tester, 'Proxies'), unorderedEquals([0, 1]));
      expect(
        tester.getTopLeft(find.byTooltip('Collapse')),
        tester.getTopLeft(find.byTooltip('Expand')),
      );
      final colorScheme = Theme.of(tester.element(_sidebarFinder)).colorScheme;
      final pane = tester.widget<Surface>(_paneFinder);
      expect(pane.color, colorScheme.chromeSurface);
      expect(
        (pane.shape! as BorderDirectional).end,
        Divider.createBorderSide(tester.element(_sidebarFinder)),
      );

      await tester.tap(find.byTooltip('Collapse'));
      await tester.pumpAndSettle();
      expect(find.text('Proxies'), findsOneWidget);
    });

    testWidgets('the pane covers the safe area around the sidebar', (
      tester,
    ) async {
      const safePadding = EdgeInsets.only(left: 40, top: 24, bottom: 16);
      await tester.pumpWidget(
        _sidebar(expanded: false, safePadding: safePadding),
      );
      final sidebar = tester.getRect(_sidebarFinder);
      expect(sidebar.width, 48 + safePadding.left);
      final toggle = tester.getTopLeft(find.byTooltip('Expand'));
      expect(toggle.dx, greaterThanOrEqualTo(sidebar.left + safePadding.left));
      expect(toggle.dy, greaterThanOrEqualTo(sidebar.top + safePadding.top));

      await openOverlay(tester);

      final pane = tester.getRect(_paneFinder);
      expect(pane.topLeft, sidebar.topLeft);
      expect(pane.height, sidebar.height);
      expect(pane.width, 220 + safePadding.left);
      expect(tester.getTopLeft(find.byTooltip('Collapse')), toggle);
    });

    testWidgets('choosing a row selects it and closes the pane', (
      tester,
    ) async {
      int? selected;
      await tester.pumpWidget(
        _sidebar(expanded: false, onSelected: (index) => selected = index),
      );
      await openOverlay(tester);

      await tester.tap(_shown('Profiles'));
      await tester.pumpAndSettle();
      expect(selected, 2);
      expect(find.text('Profiles'), findsOneWidget);
    });

    testWidgets('a tap outside or escape dismisses the pane', (tester) async {
      await tester.pumpWidget(_sidebar(expanded: false));

      await openOverlay(tester);
      await tester.tapAt(const Offset(600, 300));
      await tester.pumpAndSettle();
      expect(find.text('Proxies'), findsOneWidget);

      await openOverlay(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Proxies'), findsOneWidget);
    });

    testWidgets('a tooltip inside the pane lays out over it', (tester) async {
      await tester.pumpWidget(_sidebar(expanded: false));
      await openOverlay(tester);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(
        location: tester.getCenter(find.byTooltip('Collapse')),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Collapse'), findsOneWidget);
    });

    testWidgets('widening the window closes the pane', (tester) async {
      await tester.pumpWidget(_sidebar(expanded: false));
      await openOverlay(tester);

      await tester.pumpWidget(_sidebar(expanded: false, onToggle: () {}));
      await tester.pump();
      expect(find.text('Proxies'), findsOneWidget);
    });
  });

  group('sections', () {
    const red = Color(0xFFB3261E);
    const amber = Color(0xFFB25E00);
    const grouped = [
      SidebarDestination(glyph: Glyphs.pin, label: 'Dashboard'),
      SidebarDestination(
        glyph: Glyphs.search,
        label: 'Rules',
        badge: SidebarBadge(count: 2, semanticLabel: '2 updates'),
      ),
      SidebarDestination(
        glyph: Glyphs.sort,
        label: 'Rewrite',
        badge: SidebarBadge(count: 1, error: true, semanticLabel: 'Errors'),
      ),
      SidebarDestination(
        glyph: Glyphs.copy,
        label: 'Scripts',
        badge: SidebarBadge(count: 3),
      ),
      SidebarDestination(glyph: Glyphs.check, label: 'Tools'),
    ];

    Widget sectioned({
      bool expanded = true,
      bool closed = false,
      int selectedIndex = 0,
      VoidCallback? onToggleSection,
    }) => TestApp(
      child: HostScaffold(
        body: Row(
          children: [
            SizedBox(
              height: 600,
              child: NavigationSidebar(
                destinations: grouped,
                selectedIndex: selectedIndex,
                expanded: expanded,
                onSelected: (_) {},
                pinnedCount: 1,
                sections: [
                  const SidebarSection(length: 1),
                  const SidebarSection(title: 'Routing', length: 1),
                  SidebarSection(
                    title: 'Decryption',
                    length: 2,
                    collapsed: closed,
                    onToggle: onToggleSection,
                    semanticLabel: closed
                        ? 'Decryption, collapsed'
                        : 'Decryption, expanded',
                  ),
                ],
              ),
            ),
            const Expanded(child: SizedBox.expand()),
          ],
        ),
      ),
    );

    Finder dots(Color color) => find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is ShapeDecoration &&
          (widget.decoration as ShapeDecoration).color == color &&
          (widget.decoration as ShapeDecoration).shape is CircleBorder,
    );

    bool reachable(String label) =>
        find.text(label).hitTestable().evaluate().isNotEmpty;

    testWidgets('titles each section and pins the last rows to the foot', (
      tester,
    ) async {
      await tester.pumpWidget(sectioned());

      expect(find.text('Routing'), findsOneWidget);
      expect(find.text('Decryption'), findsOneWidget);
      final rules = tester.getTopLeft(find.text('Rules')).dy;
      expect(rules, greaterThan(tester.getTopLeft(find.text('Routing')).dy));
      expect(
        tester.getTopLeft(find.text('Tools')).dy,
        greaterThan(tester.getTopLeft(find.text('Scripts')).dy),
      );
      // The foot sits at the bottom of the pane, not after the list.
      expect(tester.getBottomLeft(find.text('Tools')).dy, greaterThan(520));
    });

    testWidgets('a row shows its count, or a red dot over it', (tester) async {
      await tester.pumpWidget(sectioned());

      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      // Rewrite has both: only the error shows.
      expect(find.text('1'), findsNothing);
      expect(dots(red), findsOneWidget);
    });

    testWidgets('a closed section hides its rows and sums their badges', (
      tester,
    ) async {
      var toggles = 0;
      await tester.pumpWidget(sectioned(onToggleSection: () => toggles++));

      await tester.tap(find.text('Decryption'));
      expect(toggles, 1);

      await tester.pumpWidget(sectioned(closed: true));
      await tester.pump(const Duration(milliseconds: 110));
      // Halfway through, the rows are partly cut off.
      expect(reachable('Rewrite'), isTrue);
      await tester.pumpAndSettle();

      expect(reachable('Rewrite'), isFalse);
      expect(reachable('Scripts'), isFalse);
      expect(reachable('Rules'), isTrue);
      // The heading carries an error from any row over the counts.
      expect(dots(red).hitTestable(), findsOneWidget);
      expect(find.text('3').hitTestable(), findsNothing);
      expect(
        tester.getCenter(dots(red).hitTestable()).dy,
        closeTo(tester.getCenter(find.text('Decryption')).dy, 1),
      );
      expect(
        tester.getTopLeft(find.text('Tools')).dy,
        greaterThan(tester.getTopLeft(find.text('Decryption')).dy),
      );
    });

    testWidgets('the merged badge sums counts when nothing failed', (
      tester,
    ) async {
      expect(
        SidebarBadge.merge(const [
          SidebarBadge(count: 2),
          null,
          SidebarBadge(count: 3),
        ]),
        const SidebarBadge(count: 5),
      );
      expect(
        SidebarBadge.merge(const [
          SidebarBadge(count: 2),
          SidebarBadge(error: true),
        ])?.error,
        isTrue,
      );
      expect(SidebarBadge.merge(const [SidebarBadge(), null]), isNull);
    });

    testWidgets('the heading reads its state and toggles for a screen reader', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var toggles = 0;
      await tester.pumpWidget(sectioned(onToggleSection: () => toggles++));

      final heading = find.semantics.byLabel('Decryption, expanded');
      expect(heading, findsOne);
      tester.semantics.tap(heading);
      expect(toggles, 1);
      semantics.dispose();
    });

    testWidgets('narrowed, a rule stands for each title and every row shows', (
      tester,
    ) async {
      await tester.pumpWidget(sectioned(expanded: false, closed: true));
      await tester.pumpAndSettle();

      expect(find.text('Decryption'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.width == 16 && widget.height == 1,
        ),
        findsNWidgets(2),
      );
      // Rows stay within reach; badges turn into dots on their icons.
      final scripts = find.byWidgetPredicate(
        (widget) => widget is AnimatedGlyph && widget.glyph == Glyphs.copy,
      );
      expect(scripts.hitTestable(), findsOneWidget);
      expect(dots(amber), findsNWidgets(2));
      expect(dots(red), findsOneWidget);
    });
  });
}
