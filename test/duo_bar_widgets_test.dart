import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

import 'duo_test_support.dart';

/// The cover display's camera: 84 wide at the top of the strip.
DuoState _coverPose() => duo(
  hinge: DuoHingeStatus.closed,
  regions: [occlusion(const Rect.fromLTWH(382, 0, 84, 170))],
);

List<DuoBarItem> _actions(int count) => [
  for (var i = 0; i < count; i++)
    DuoBarItem(symbol: 'symbol$i', title: 'Action $i', endsGroup: true),
];

void main() {
  tearDown(() => debugSetDuoState(null));

  group('DuoBarStyle', () {
    test('capsuleExtent is the buttons plus the gap below', () {
      const style = DuoBarStyle(itemHeight: 40, groupSpacing: 10);
      expect(style.capsuleExtent(1), 50);
      expect(style.capsuleExtent(3), 130);
    });

    test('copyWith replaces only what it is given', () {
      const style = DuoBarStyle(capsuleWidth: 44, overflowTitle: 'More');
      final wider = style.copyWith(capsuleWidth: 60);

      expect(wider.capsuleWidth, 60);
      expect(wider.overflowTitle, 'More');
      expect(style.copyWith(), style);
    });

    test('every visual knob survives copyWith and compares by value', () {
      const style = DuoBarStyle();
      final tuned = style.copyWith(
        symbolPointSize: 22,
        titlePadding: const EdgeInsetsDirectional.only(start: 32),
        titleBackdropRadius: 16,
        compression: DuoBarCompression.prefersBarItems,
      );

      expect(tuned.symbolPointSize, 22);
      expect(tuned.titlePadding, const EdgeInsetsDirectional.only(start: 32));
      expect(tuned.titleBackdropRadius, 16);
      expect(tuned.compression, DuoBarCompression.prefersBarItems);
      expect(tuned, isNot(style));
      expect(tuned, style.copyWith(
        symbolPointSize: 22,
        titlePadding: const EdgeInsetsDirectional.only(start: 32),
        titleBackdropRadius: 16,
        compression: DuoBarCompression.prefersBarItems,
      ));

      // Defaults match what the system draws.
      expect(style.symbolPointSize, kDuoBarSymbolPointSize);
      expect(style.titleBackdropRadius, 0);
    });

    test('values compare by their fields', () {
      const a = DuoBarStyle(capsuleWidth: 50, tint: Color(0xFF00FF00));
      const b = DuoBarStyle(capsuleWidth: 50, tint: Color(0xFF00FF00));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const DuoBarStyle(capsuleWidth: 51)));
      expect(a, isNot(const Object()));
    });
  });

  group('DuoBarTheme', () {
    testWidgets('gives the system defaults when there is none', (tester) async {
      late DuoBarStyle style;
      await tester.pumpWidget(
        host(
          child: Builder(
            builder: (context) {
              style = DuoBarTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(style, const DuoBarStyle());
    });

    testWidgets('hands the nearest style down the tree', (tester) async {
      const custom = DuoBarStyle(capsuleWidth: 60);
      late DuoBarStyle style;

      await tester.pumpWidget(
        host(
          child: DuoBarTheme(
            style: custom,
            child: Builder(
              builder: (context) {
                style = DuoBarTheme.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(style, custom);
    });

    testWidgets('notifies only when the style actually changes', (
      tester,
    ) async {
      const style = DuoBarStyle(capsuleWidth: 60);
      const theme = DuoBarTheme(style: style, child: SizedBox.shrink());

      expect(
        theme.updateShouldNotify(
          const DuoBarTheme(style: style, child: SizedBox.shrink()),
        ),
        isFalse,
      );
      expect(
        theme.updateShouldNotify(
          const DuoBarTheme(
            style: DuoBarStyle(capsuleWidth: 44),
            child: SizedBox.shrink(),
          ),
        ),
        isTrue,
      );
    });
  });

  group('DuoGlassCapsule', () {
    testWidgets('lays out a capsule per button off iOS', (tester) async {
      await tester.pumpWidget(
        host(
          child: const Center(
            child: SizedBox(
              width: 44,
              height: 88,
              child: DuoGlassCapsule(
                items: [DuoBarItem(symbol: 'a'), DuoBarItem(symbol: 'b')],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DuoGlassCapsule), findsOneWidget);
      expect(tester.getSize(find.byType(DuoGlassCapsule)), const Size(44, 88));
    });

    testWidgets('reports a press from the fallback capsule', (tester) async {
      final pressed = <(int, int)>[];
      await tester.pumpWidget(
        host(
          child: Center(
            child: SizedBox(
              width: 44,
              height: 88,
              child: DuoGlassCapsule(
                items: [
                  DuoBarItem(symbol: 'a', onPressed: () => pressed.add((0, -1))),
                  DuoBarItem(symbol: 'b', onPressed: () => pressed.add((1, -1))),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tapAt(
        tester.getCenter(find.byType(DuoGlassCapsule)) - const Offset(0, 22),
      );
      await tester.pump();

      expect(pressed, [(0, -1)]);
    });

    testWidgets('survives a rebuild with new contents', (tester) async {
      Widget capsule(List<String> symbols) => host(
        child: Center(
          child: SizedBox(
            width: 44,
            height: 44.0 * symbols.length,
            child: DuoGlassCapsule(
              items: [for (final s in symbols) DuoBarItem(symbol: s)],
              selectedIndex: 0,
            ),
          ),
        ),
      );

      await tester.pumpWidget(capsule(['a']));
      await tester.pumpWidget(capsule(['a', 'b']));

      expect(tester.getSize(find.byType(DuoGlassCapsule)).height, 88);
    });
  });

  group('DuoVerticalBar', () {
    testWidgets('stacks leading, toolbar groups and the tab bar', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(duoCoverSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        host(
          size: duoCoverSize,
          child: Align(
            alignment: Alignment.centerRight,
            child: DuoVerticalBar(
              state: _coverPose(),
              leading: const DuoBarItem(symbol: 'chevron.backward'),
              actions: _actions(2),
              tabs: const [
                DuoBarItem(symbol: 'info.circle'),
                DuoBarItem(symbol: 'square.split.2x1'),
              ],
              selectedTab: 0,
            ),
          ),
        ),
      );

      // Leading, two toolbar groups, and the tab bar: four capsules.
      expect(find.byType(DuoGlassCapsule), findsNWidgets(4));
      expect(tester.getSize(find.byType(DuoVerticalBar)).width, 84);
    });

    testWidgets('adds an overflow capsule when the strip runs out', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(duoCoverSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        host(
          size: duoCoverSize,
          child: Align(
            alignment: Alignment.centerRight,
            child: DuoVerticalBar(state: _coverPose(), actions: _actions(12)),
          ),
        ),
      );

      // Far more groups than fit: the tail collapses into one capsule, so the
      // count lands well under the twelve asked for.
      final capsules = tester.widgetList<DuoGlassCapsule>(
        find.byType(DuoGlassCapsule),
      );
      expect(capsules.length, lessThan(12));
      expect(capsules.last.items.single.menu, isNotEmpty);
      expect(capsules.last.items.single.symbol, kDuoOverflowSymbol);
    });

    testWidgets('honours a style override', (tester) async {
      await tester.binding.setSurfaceSize(duoCoverSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        host(
          size: duoCoverSize,
          child: Align(
            alignment: Alignment.centerRight,
            child: DuoVerticalBar(
              state: _coverPose(),
              actions: _actions(1),
              style: const DuoBarStyle(stripWidth: 120, capsuleWidth: 60),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(DuoVerticalBar)).width, 120);
      expect(tester.getSize(find.byType(DuoGlassCapsule).first).width, 60);
    });

    testWidgets('takes its style from an ancestor theme', (tester) async {
      await tester.binding.setSurfaceSize(duoCoverSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        host(
          size: duoCoverSize,
          child: DuoBarTheme(
            style: const DuoBarStyle(stripWidth: 100),
            child: Align(
              alignment: Alignment.centerRight,
              child: DuoVerticalBar(state: _coverPose(), actions: _actions(1)),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(DuoVerticalBar)).width, 100);
    });
  });

  group('DuoBarCompression', () {
    /// Enough actions that the strip cannot hold them all.
    List<DuoBarItem> crowded() => _actions(12);

    testWidgets('by default the toolbar overflows and the tab bar stays whole', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(duoCoverSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        host(
          size: duoCoverSize,
          child: Align(
            alignment: Alignment.centerRight,
            child: DuoVerticalBar(
              state: _coverPose(),
              actions: crowded(),
              tabs: const [
                DuoBarItem(symbol: 'one'),
                DuoBarItem(symbol: 'two'),
                DuoBarItem(symbol: 'three'),
              ],
              selectedTab: 1,
            ),
          ),
        ),
      );

      final capsules = tester
          .widgetList<DuoGlassCapsule>(find.byType(DuoGlassCapsule))
          .toList();
      // The tab capsule keeps all three tabs, and something overflowed.
      expect([for (final i in capsules.last.items) i.symbol], ['one', 'two', 'three']);
      expect(
        capsules.any((c) => c.items.single.symbol == kDuoOverflowSymbol),
        isTrue,
      );
    });

    testWidgets('prefersBarItems collapses the tab bar into one button', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(duoCoverSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        host(
          size: duoCoverSize,
          child: Align(
            alignment: Alignment.centerRight,
            child: DuoVerticalBar(
              state: _coverPose(),
              actions: crowded(),
              tabs: const [
                DuoBarItem(symbol: 'one', title: 'One'),
                DuoBarItem(symbol: 'two', title: 'Two'),
                DuoBarItem(symbol: 'three', title: 'Three'),
              ],
              selectedTab: 1,
              style: const DuoBarStyle(
                compression: DuoBarCompression.prefersBarItems,
              ),
            ),
          ),
        ),
      );

      final tabCapsule = tester
          .widgetList<DuoGlassCapsule>(find.byType(DuoGlassCapsule))
          .last;
      // One button, showing where you are, with every tab behind it.
      expect(tabCapsule.items.single.symbol, 'two');
      expect(tabCapsule.items.single.menu, hasLength(3));
    });

    testWidgets('leaves the tab bar alone when everything fits', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(duoCoverSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        host(
          size: duoCoverSize,
          child: Align(
            alignment: Alignment.centerRight,
            child: DuoVerticalBar(
              state: _coverPose(),
              actions: _actions(1),
              tabs: const [
                DuoBarItem(symbol: 'one'),
                DuoBarItem(symbol: 'two'),
              ],
              selectedTab: 0,
              style: const DuoBarStyle(
                compression: DuoBarCompression.prefersBarItems,
              ),
            ),
          ),
        ),
      );

      expect(
        [
          for (final item
              in tester
                  .widgetList<DuoGlassCapsule>(find.byType(DuoGlassCapsule))
                  .last
                  .items)
            item.symbol,
        ],
        ['one', 'two'],
      );
    });

    test('only prefersBarItems compresses the tab bar', () {
      expect(DuoBarCompression.automatic.compressesTabBar, isFalse);
      expect(DuoBarCompression.prefersTabBar.compressesTabBar, isFalse);
      expect(DuoBarCompression.prefersBarItems.compressesTabBar, isTrue);
    });
  });

  group('duoCapsuleExtent', () {
    test('matches the style it is measured against', () {
      expect(duoCapsuleExtent(2), kDuoBarItemHeight * 2 + kDuoBarGroupSpacing);
      expect(
        duoCapsuleExtent(
          2,
          style: const DuoBarStyle(itemHeight: 30, groupSpacing: 5),
        ),
        65,
      );
    });
  });

  group('DuoVerticalBar press routing', () {
    /// The capsules the bar builds, so what each button carries can be read
    /// back the way the native side sees it.
    Future<List<DuoGlassCapsule>> capsulesFor(
      WidgetTester tester,
      List<DuoBarItem> actions,
    ) async {
      await tester.binding.setSurfaceSize(duoCoverSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        host(
          size: duoCoverSize,
          child: Align(
            alignment: Alignment.centerRight,
            child: DuoVerticalBar(state: _coverPose(), actions: actions),
          ),
        ),
      );
      return tester
          .widgetList<DuoGlassCapsule>(find.byType(DuoGlassCapsule))
          .toList();
    }

    testWidgets('a capsule carries the item it was built from', (tester) async {
      var pressed = 0;
      final capsules = await capsulesFor(tester, [
        DuoBarItem(symbol: 'a', title: 'A', onPressed: () => pressed++),
      ]);

      final item = capsules.first.items.single;
      expect(item.symbol, 'a');
      expect(item.title, 'A');

      item.onPressed!();
      expect(pressed, 1);
    });

    testWidgets('overflowed items keep their callbacks in the menu', (
      tester,
    ) async {
      var chosen = '';
      final capsules = await capsulesFor(tester, [
        for (var i = 0; i < 12; i++)
          DuoBarItem(
            symbol: 'symbol$i',
            title: 'Action $i',
            endsGroup: true,
            onPressed: () => chosen = 'Action $i',
          ),
      ]);

      final overflow = capsules.firstWhere((c) => c.items.single.menu.isNotEmpty);
      final entries = overflow.items.single.menu;

      entries[1].onPressed!();
      expect(chosen, entries[1].title);

      // The overflow button itself opens the menu rather than acting.
      expect(overflow.items.single.onPressed, isNull);
    });

    testWidgets('a fallback tap runs the item behind it', (tester) async {
      final pressed = <String>[];
      await tester.pumpWidget(
        host(
          child: Center(
            child: SizedBox(
              width: 44,
              height: 88,
              child: DuoGlassCapsule(
                items: [
                  DuoBarItem(symbol: 'a', onPressed: () => pressed.add('a')),
                  DuoBarItem(symbol: 'b', onPressed: () => pressed.add('b')),
                ],
              ),
            ),
          ),
        ),
      );

      final centre = tester.getCenter(find.byType(DuoGlassCapsule));
      await tester.tapAt(centre + const Offset(0, 22));
      await tester.pump();

      expect(pressed, ['b']);
    });
  });

  group('DuoBarScaffold customisation', () {
    testWidgets('the style places and shapes the title', (tester) async {
      await tester.binding.setSurfaceSize(duoInnerSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugSetDuoState(duo());

      await tester.pumpWidget(
        host(
          child: const DuoBarScaffold(
            title: Text('Library'),
            body: SizedBox.expand(),
            style: DuoBarStyle(
              titlePadding: EdgeInsetsDirectional.only(start: 40),
              titleBackdropRadius: 12,
            ),
          ),
        ),
      );

      expect(tester.getTopLeft(find.text('Library')).dx, 40);
      expect(
        tester.widget<DuoGlassSurface>(find.byType(DuoGlassSurface))
            .borderRadius,
        12,
      );
    });

    testWidgets('titleBackdrop: false drops the material', (tester) async {
      await tester.binding.setSurfaceSize(duoInnerSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugSetDuoState(duo());

      await tester.pumpWidget(
        host(
          child: const DuoBarScaffold(
            title: Text('Library'),
            body: SizedBox.expand(),
            titleBackdrop: false,
          ),
        ),
      );

      expect(find.byType(DuoGlassSurface), findsNothing);
      expect(find.text('Library'), findsOneWidget);
    });

    testWidgets('the symbol size reaches the capsules', (tester) async {
      await tester.binding.setSurfaceSize(duoCoverSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        host(
          size: duoCoverSize,
          child: Align(
            alignment: Alignment.centerRight,
            child: DuoVerticalBar(
              state: _coverPose(),
              actions: _actions(1),
              style: const DuoBarStyle(symbolPointSize: 24),
            ),
          ),
        ),
      );

      expect(
        tester.widget<DuoGlassCapsule>(find.byType(DuoGlassCapsule).first)
            .symbolPointSize,
        24,
      );
    });
  });

  group('DuoBarScaffold', () {
    testWidgets('shows a leading-edge title above the body', (tester) async {
      await tester.binding.setSurfaceSize(duoInnerSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugSetDuoState(duo());

      await tester.pumpWidget(
        host(
          child: const DuoBarScaffold(
            title: Text('Fold Duo'),
            body: SizedBox.expand(child: Text('body')),
          ),
        ),
      );

      expect(find.text('Fold Duo'), findsOneWidget);
      // The title band sits above the body, inset from the leading edge.
      expect(tester.getTopLeft(find.text('Fold Duo')).dx, 20);
      expect(
        tester.getSize(find.text('body')).height,
        669 - kDuoTitleBandHeight,
      );
    });

    testWidgets('reserves the strip on the left when the bar is there', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(duoInnerSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugSetDuoState(duo(edge: DuoVerticalBarEdge.leading));

      await tester.pumpWidget(
        host(
          viewPadding: const EdgeInsets.only(left: 84, bottom: 34),
          child: const DuoBarScaffold(
            body: SizedBox.expand(child: Text('body')),
          ),
        ),
      );

      expect(tester.getTopLeft(find.text('body')).dx, 84);
      expect(tester.getTopLeft(find.byType(DuoVerticalBar)).dx, 0);
    });

    testWidgets('returns the body bare when there is no horizontal chrome', (
      tester,
    ) async {
      debugSetDuoState(duo(edge: DuoVerticalBarEdge.unspecified));

      await tester.pumpWidget(
        host(
          viewPadding: phoneViewPadding,
          child: const DuoBarScaffold(body: Text('body')),
        ),
      );

      expect(find.text('body'), findsOneWidget);
      expect(find.byType(DuoVerticalBar), findsNothing);
    });
  });
}
