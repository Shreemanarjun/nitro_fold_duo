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
              child: DuoGlassCapsule(symbols: ['a', 'b']),
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
                symbols: const ['a', 'b'],
                onPressed: (index, menuIndex) =>
                    pressed.add((index, menuIndex)),
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
            child: DuoGlassCapsule(symbols: symbols, selectedIndex: 0),
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
      expect(capsules.last.menus[0], isNotNull);
      expect(capsules.last.symbols.single, kDuoOverflowSymbol);
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
    /// The capsule the bar builds for [items], so its callback can be driven
    /// the way a native button press does.
    Future<DuoGlassCapsule> capsuleFor(
      WidgetTester tester,
      List<DuoBarItem> items,
    ) async {
      await tester.binding.setSurfaceSize(duoCoverSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        host(
          size: duoCoverSize,
          child: Align(
            alignment: Alignment.centerRight,
            child: DuoVerticalBar(state: _coverPose(), actions: items),
          ),
        ),
      );
      return tester.widget<DuoGlassCapsule>(find.byType(DuoGlassCapsule).first);
    }

    testWidgets('a plain press runs the item it belongs to', (tester) async {
      var pressed = 0;
      final capsule = await capsuleFor(tester, [
        DuoBarItem(symbol: 'a', onPressed: () => pressed++),
      ]);

      capsule.onPressed!(0, -1);

      expect(pressed, 1);
    });

    testWidgets('a menu choice runs the overflowed item', (tester) async {
      var chosen = '';
      final actions = [
        for (var i = 0; i < 12; i++)
          DuoBarItem(
            symbol: 'symbol\$i',
            title: 'Action \$i',
            endsGroup: true,
            onPressed: () => chosen = 'Action \$i',
          ),
      ];
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

      final overflow = tester.widgetList<DuoGlassCapsule>(
        find.byType(DuoGlassCapsule),
      ).firstWhere((c) => c.menus.isNotEmpty);
      final entries = overflow.menus[0]!;

      overflow.onPressed!(0, 1);
      expect(chosen, entries[1].title);

      // A choice past the end of the menu is ignored rather than throwing.
      overflow.onPressed!(0, entries.length + 5);
      expect(chosen, entries[1].title);

      // So is a press on a button with no menu behind it.
      overflow.onPressed!(0, -1);
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
