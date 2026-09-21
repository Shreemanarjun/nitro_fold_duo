import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

DuoReservedRegion _occlusion(Rect r, {bool isActive = true}) =>
    DuoReservedRegion(
      kind: DuoRegionKind.occlusion,
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      marginLeft: 0,
      marginTop: 0,
      marginRight: 0,
      marginBottom: 0,
      isActive: isActive,
    );

DuoState _state({
  List<DuoReservedRegion> regions = const [],
  DuoVerticalBarEdge edge = DuoVerticalBarEdge.trailing,
  bool isSupported = true,
}) => DuoState(
  isSupported: isSupported,
  hingeStatus: DuoHingeStatus.partiallyOpen,
  verticalBarEdge: edge,
  hingeAngle: 2.2,
  regions: regions,
  cornerInsets: const DuoInsets(left: 0, top: 0, right: 0, bottom: 0),
);

/// The inner display in landscape, as measured on the iPhone Duo simulator.
const _duoSize = Size(951, 669);
const _duoViewPadding = EdgeInsets.only(right: 84, bottom: 34);

Widget _host({
  required Widget child,
  Size size = _duoSize,
  EdgeInsets viewPadding = _duoViewPadding,
}) => MediaQuery(
  data: MediaQueryData(
    size: size,
    viewPadding: viewPadding,
    padding: viewPadding,
  ),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

void main() {
  group('DuoLayout.barSide', () {
    test('a side-only inset with no top inset is a Duo strip', () {
      expect(DuoLayout.barSide(_duoViewPadding), DuoBarSide.right);
      expect(
        DuoLayout.barSide(const EdgeInsets.only(left: 84, bottom: 34)),
        DuoBarSide.left,
      );
    });

    test('a top inset means the system keeps bars horizontal', () {
      // Any other iPhone in portrait, and the Duo inner display in portrait.
      expect(
        DuoLayout.barSide(const EdgeInsets.only(top: 59, bottom: 34)),
        isNull,
      );
    });

    test('insets on both sides are an ordinary phone in landscape', () {
      expect(
        DuoLayout.barSide(
          const EdgeInsets.only(left: 59, right: 59, bottom: 21),
        ),
        isNull,
      );
    });

    test('no insets at all is not a strip', () {
      expect(DuoLayout.barSide(EdgeInsets.zero), isNull);
    });

    test('an unspecified bar edge vetoes the padding guess', () {
      expect(
        DuoLayout.barSide(
          _duoViewPadding,
          state: _state(edge: DuoVerticalBarEdge.unspecified),
        ),
        isNull,
      );
      // ...but only when the system actually answered.
      expect(
        DuoLayout.barSide(
          _duoViewPadding,
          state: _state(
            edge: DuoVerticalBarEdge.unspecified,
            isSupported: false,
          ),
        ),
        DuoBarSide.right,
      );
    });
  });

  group('DuoLayout.stripWidth', () {
    test('takes the system inset', () {
      expect(DuoLayout.stripWidth(_duoViewPadding), 84);
    });

    test('falls back when the inset is reported as zero', () {
      expect(DuoLayout.stripWidth(EdgeInsets.zero), kDuoVerticalBarWidth);
    });
  });

  group('DuoLayout.barInsets', () {
    ({double top, double bottom}) insetsFor(List<DuoReservedRegion> regions) =>
        DuoLayout.barInsets(
          size: _duoSize,
          viewPadding: _duoViewPadding,
          state: _state(regions: regions),
        );

    test('clears a camera at the top of the strip', () {
      // The occlusion measured on the device: 867,0 84x120.
      final insets = insetsFor([
        _occlusion(const Rect.fromLTWH(867, 0, 84, 120)),
      ]);
      expect(insets.top, 120);
      expect(insets.bottom, kDuoBarEdgeMargin);
    });

    test('clears a camera at the bottom of the strip', () {
      final insets = insetsFor([
        _occlusion(const Rect.fromLTWH(867, 549, 84, 120)),
      ]);
      expect(insets.top, kDuoBarEdgeMargin);
      expect(insets.bottom, 669 - 549 + kDuoBarRegionGap);
    });

    test('the lowest camera in the strip sets the bottom clearance', () {
      // Two regions in the lower half: the one that reaches further up wins.
      final insets = insetsFor([
        _occlusion(const Rect.fromLTWH(867, 600, 84, 69)),
        _occlusion(const Rect.fromLTWH(867, 500, 84, 169)),
      ]);
      expect(insets.bottom, 669 - 500 + kDuoBarRegionGap);
    });

    test(
      'an empty strip means nothing has been reported for this pose yet',
      () {
        expect(insetsFor([]).top, kDuoStatusClusterFallbackHeight);
      },
    );

    test('a region outside the strip does not push the controls', () {
      // Sits on the page body, not in the strip.
      expect(
        insetsFor([_occlusion(const Rect.fromLTWH(0, 0, 80, 80))]).top,
        kDuoStatusClusterFallbackHeight,
      );
    });

    test('a reading left over from another pose is discarded', () {
      // Taller than this window: it belongs to the pose we just left.
      expect(
        insetsFor([_occlusion(const Rect.fromLTWH(867, 0, 84, 900))]).top,
        kDuoStatusClusterFallbackHeight,
      );
    });

    test('an inactive camera does not reserve room', () {
      expect(
        insetsFor([
          _occlusion(const Rect.fromLTWH(867, 0, 84, 120), isActive: false),
        ]).top,
        kDuoStatusClusterFallbackHeight,
      );
    });
  });

  group('DuoVerticalBar.groupsOf', () {
    test('consecutive actions share a capsule until one ends the group', () {
      final groups = DuoVerticalBar.groupsOf(const [
        DuoBarItem(symbol: 'a', title: 'a'),
        DuoBarItem(symbol: 'b', title: 'b', endsGroup: true),
        DuoBarItem(symbol: 'c', title: 'c'),
      ]);
      expect(groups.map((g) => g.map((i) => i.symbol).toList()), [
        ['a', 'b'],
        ['c'],
      ]);
    });

    test('no actions means no capsules', () {
      expect(DuoVerticalBar.groupsOf(const []), isEmpty);
    });
  });

  group('duoBarOverflow', () {
    // One capsule costs 44 per button plus a 12 gap: 56 for one, 100 for two.
    const groups = [
      [
        DuoBarItem(symbol: 'a', title: 'a'),
        DuoBarItem(symbol: 'b', title: 'b'),
      ],
      [DuoBarItem(symbol: 'c', title: 'c')],
      [DuoBarItem(symbol: 'd', title: 'd')],
    ];
    const total = 100.0 + 56 + 56;

    List<String> symbolsOf(List<DuoBarItem> items) => [
      for (final item in items) item.symbol,
    ];

    test('nothing overflows when everything fits exactly', () {
      final fitted = duoBarOverflow(groups: groups, available: total);
      expect(fitted.visible, groups);
      expect(fitted.overflow, isEmpty);
    });

    test('room for the overflow capsule comes out of the budget first', () {
      // One point short: the last two groups go to the menu, not just one,
      // because the overflow capsule needs its own 56 points.
      final fitted = duoBarOverflow(groups: groups, available: total - 1);
      expect(fitted.visible.map(symbolsOf), [
        ['a', 'b'],
      ]);
      expect(symbolsOf(fitted.overflow), ['c', 'd']);
    });

    test('a group is never split across the strip and the menu', () {
      // Room for the overflow capsule and one 56-point group only, so the
      // leading two-button group cannot be half shown.
      final fitted = duoBarOverflow(groups: groups, available: 56.0 + 56);
      expect(fitted.visible, isEmpty);
      expect(symbolsOf(fitted.overflow), ['a', 'b', 'c', 'd']);
    });

    test('a strip with no room at all sends everything to the menu', () {
      final fitted = duoBarOverflow(groups: groups, available: 0);
      expect(fitted.visible, isEmpty);
      expect(symbolsOf(fitted.overflow), ['a', 'b', 'c', 'd']);
    });

    test('no actions never produces an overflow capsule', () {
      final fitted = duoBarOverflow(groups: const [], available: 0);
      expect(fitted.visible, isEmpty);
      expect(fitted.overflow, isEmpty);
    });

    // Three 56-point capsules against 130 points: the overflow capsule takes
    // 56 of it, leaving room for one of them. Priority decides which.
    const three = 130.0;

    test('a low priority goes before the capsule below it', () {
      final fitted = duoBarOverflow(
        available: three,
        groups: const [
          [
            DuoBarItem(
              symbol: 'a',
              title: 'a',
              visibilityPriority: DuoBarVisibilityPriority.low,
            ),
          ],
          [DuoBarItem(symbol: 'b', title: 'b')],
          [DuoBarItem(symbol: 'c', title: 'c')],
        ],
      );

      expect(fitted.visible.map(symbolsOf), [
        ['b'],
      ]);
      expect(symbolsOf(fitted.overflow), ['a', 'c']);
    });

    test('a high priority keeps the capsule that would have gone first', () {
      final fitted = duoBarOverflow(
        available: three,
        groups: const [
          [DuoBarItem(symbol: 'a', title: 'a')],
          [DuoBarItem(symbol: 'b', title: 'b')],
          [
            DuoBarItem(
              symbol: 'c',
              title: 'c',
              visibilityPriority: DuoBarVisibilityPriority.high,
            ),
          ],
        ],
      );

      expect(fitted.visible.map(symbolsOf), [
        ['c'],
      ]);
      expect(symbolsOf(fitted.overflow), ['a', 'b']);
    });

    test('a capsule is as important as its most important button', () {
      // Room for the overflow capsule and 114 points. Left alone the two
      // single capsules would survive; the pair outranks them because one of
      // its buttons does.
      final fitted = duoBarOverflow(
        available: 170,
        groups: const [
          [DuoBarItem(symbol: 'a', title: 'a')],
          [
            DuoBarItem(symbol: 'b', title: 'b'),
            DuoBarItem(
              symbol: 'c',
              title: 'c',
              visibilityPriority: DuoBarVisibilityPriority.high,
            ),
          ],
          [DuoBarItem(symbol: 'd', title: 'd')],
        ],
      );

      expect(fitted.visible.map(symbolsOf), [
        ['b', 'c'],
      ]);
      expect(symbolsOf(fitted.overflow), ['a', 'd']);
    });
  });

  group('DuoBarVisibilityPriority', () {
    test('ranks low below automatic and high above it', () {
      expect(
        DuoBarVisibilityPriority.low.rank,
        lessThan(DuoBarVisibilityPriority.automatic.rank),
      );
      expect(
        DuoBarVisibilityPriority.high.rank,
        greaterThan(DuoBarVisibilityPriority.automatic.rank),
      );
    });

    test('derives a priority either side of another', () {
      expect(
        DuoBarVisibilityPriority.lowerThan(DuoBarVisibilityPriority.low).rank,
        lessThan(DuoBarVisibilityPriority.low.rank),
      );
      expect(
        DuoBarVisibilityPriority.higherThan(DuoBarVisibilityPriority.high).rank,
        greaterThan(DuoBarVisibilityPriority.high.rank),
      );
    });
  });

  group('DuoBarItem', () {
    test('copyWith keeps the menu it already had', () {
      const item = DuoBarItem(
        symbol: 'a',
        title: 'A',
        endsGroup: true,
        menu: [DuoBarItem(symbol: 'x', title: 'x')],
        visibilityPriority: DuoBarVisibilityPriority.high,
      );

      final same = item.copyWith();
      expect(same.symbol, 'a');
      expect(same.title, 'A');
      expect(same.endsGroup, isTrue);
      expect(same.menu, item.menu);
      expect(same.visibilityPriority, DuoBarVisibilityPriority.high);

      expect(
        item
            .copyWith(
              menu: const [DuoBarItem(symbol: 'y', title: 'y')],
            )
            .menu
            .single
            .symbol,
        'y',
      );
    });
  });

  group('DuoBarScaffold', () {
    testWidgets('draws the vertical bar and keeps the body clear of it', (
      tester,
    ) async {
      // Match the render surface to the window the MediaQuery describes, so
      // the strip is measured against the same box the widget lays out in.
      await tester.binding.setSurfaceSize(_duoSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _host(
          child: DuoBarScaffold(
            body: const SizedBox.expand(child: Text('body')),
            actions: const [
              DuoBarItem(symbol: 'gearshape', title: 'gearshape'),
            ],
            horizontalChrome: (context, body) =>
                const Text('horizontal chrome'),
          ),
        ),
      );

      expect(find.text('horizontal chrome'), findsNothing);
      expect(find.byType(DuoVerticalBar), findsOneWidget);

      // 84 points of the 951-wide window belong to the strip.
      expect(tester.getSize(find.text('body')).width, 951 - 84);
    });

    testWidgets('falls back to horizontal chrome where there is no strip', (
      tester,
    ) async {
      const phone = Size(430, 932);
      await tester.binding.setSurfaceSize(phone);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _host(
          size: phone,
          viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
          child: DuoBarScaffold(
            body: const Text('body'),
            actions: const [
              DuoBarItem(symbol: 'gearshape', title: 'gearshape'),
            ],
            horizontalChrome: (context, body) =>
                const Text('horizontal chrome'),
          ),
        ),
      );

      expect(find.byType(DuoVerticalBar), findsNothing);
      expect(find.text('horizontal chrome'), findsOneWidget);
    });

    testWidgets('a background runs the full width, under the strip', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(_duoSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _host(
          child: const DuoBarScaffold(
            body: SizedBox.expand(child: Text('body')),
            actions: [DuoBarItem(symbol: 'gearshape', title: 'gearshape')],
            background: ColoredBox(
              key: Key('background'),
              color: Color(0xFF123456),
            ),
          ),
        ),
      );

      // The body keeps clear of the strip; the background does not.
      expect(tester.getSize(find.text('body')).width, 951 - 84);
      expect(tester.getSize(find.byKey(const Key('background'))).width, 951);
    });

    testWidgets('the background is drawn behind horizontal chrome too', (
      tester,
    ) async {
      const phone = Size(430, 932);
      await tester.binding.setSurfaceSize(phone);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _host(
          size: phone,
          viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
          child: DuoBarScaffold(
            body: const Text('body'),
            background: const ColoredBox(
              key: Key('background'),
              color: Color(0xFF123456),
            ),
            horizontalChrome: (context, body) =>
                const Text('horizontal chrome'),
          ),
        ),
      );

      expect(find.text('horizontal chrome'), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('background'))).width, 430);
    });
  });
}
