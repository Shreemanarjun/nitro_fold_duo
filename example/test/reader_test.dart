import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';
import 'package:nitro_fold_duo_example/app.dart';
import 'package:nitro_fold_duo_example/data/articles.dart';
import 'package:nitro_fold_duo_example/pages/home_page.dart';
import 'package:nitro_fold_duo_example/widgets/article_list.dart';

/// The inner display in landscape, folded: a division down the middle.
DuoState _folded() => DuoState(
  isSupported: true,
  hingeStatus: DuoHingeStatus.partiallyOpen,
  verticalBarEdge: DuoVerticalBarEdge.trailing,
  hingeAngle: 2.2,
  regions: const [
    DuoReservedRegion(
      kind: DuoRegionKind.division,
      left: 456,
      top: 0,
      width: 40,
      height: 669,
      marginLeft: 0,
      marginTop: 0,
      marginRight: 0,
      marginBottom: 0,
      isActive: true,
    ),
  ],
  cornerInsets: const DuoInsets(left: 0, top: 0, right: 84, bottom: 34),
);

const _phoneSize = Size(430, 932);

/// Any other iPhone: a top inset, so the chrome stays horizontal. The render
/// surface is set to match, or the layout is laid out for one size while being
/// told it is another.
Future<void> pumpPhone(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_phoneSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    const MediaQuery(
      data: MediaQueryData(
        size: _phoneSize,
        viewPadding: EdgeInsets.only(top: 59, bottom: 34),
        padding: EdgeInsets.only(top: 59, bottom: 34),
      ),
      child: DuoDemoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

const _duoSize = Size(951, 669);
const _duoPadding = EdgeInsets.only(right: 84, bottom: 34);

/// The inner display in landscape, folded: a side inset, so the chrome moves
/// into the vertical strip and the bar's own buttons are the only controls.
Future<void> pumpDuo(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_duoSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  debugSetDuoState(_folded());
  await tester.pumpWidget(
    const MediaQuery(
      data: MediaQueryData(
        size: _duoSize,
        viewPadding: _duoPadding,
        padding: _duoPadding,
      ),
      child: DuoDemoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Every item the bar put in a capsule, menus included, so the callbacks the
/// native side would fire can be run here.
List<DuoBarItem> barItems(WidgetTester tester) => [
  for (final capsule in tester.widgetList<DuoGlassCapsule>(
    find.byType(DuoGlassCapsule),
  ))
    for (final item in capsule.items) ...[item, ...item.menu],
];

void main() {
  tearDown(() => debugSetDuoState(null));

  testWidgets('the reader opens on the first article', (tester) async {
    await pumpPhone(tester);

    expect(find.byKey(const Key('articleList')), findsOneWidget);
    expect(find.text(articles.first.title), findsWidgets);
    expect(
      tester.widget<Text>(find.byKey(const Key('detailTitle'))).data,
      articles.first.title,
    );
  });

  testWidgets('choosing an article swaps the detail pane', (tester) async {
    await pumpPhone(tester);

    await tester.tap(find.byKey(const Key('article_2')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('detailTitle'))).data,
      articles[2].title,
    );
  });

  testWidgets('the panes land either side of the fold', (tester) async {
    await tester.binding.setSurfaceSize(const Size(951, 669));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    debugSetDuoState(_folded());

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(951, 669),
          viewPadding: EdgeInsets.only(right: 84, bottom: 34),
          padding: EdgeInsets.only(right: 84, bottom: 34),
        ),
        child: const DuoDemoApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The list stops at the crease and the article starts after it.
    final list = tester.getRect(find.byKey(const Key('articleList')));
    final detail = tester.getRect(find.byKey(const Key('articleDetail')));
    expect(list.right, lessThanOrEqualTo(456));
    expect(detail.left, greaterThanOrEqualTo(496));
  });

  testWidgets('the tab bar switches to the state readout', (tester) async {
    await pumpPhone(tester);

    await tester.tap(find.byIcon(DemoTab.state.icon));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('readout')), findsOneWidget);
    expect(find.text('supported: false'), findsOneWidget);
  });

  testWidgets('a toolbar action is recorded', (tester) async {
    await pumpPhone(tester);

    await tester.tap(find.byKey(const Key('horizontalShare')));
    await tester.tap(find.byIcon(DemoTab.state.icon));
    await tester.pumpAndSettle();

    expect(find.text('action: share'), findsOneWidget);
  });

  testWidgets('the fold-aware dialog opens and closes', (tester) async {
    await pumpPhone(tester);

    await tester.tap(find.byKey(const Key('horizontalDialog')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('foldDialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('foldDialogClose')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foldDialog')), findsNothing);
  });

  testWidgets('the detail page pushes and pops', (tester) async {
    await pumpPhone(tester);

    await tester.tap(find.byKey(const Key('horizontalDetail')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detailBody')), findsOneWidget);

    await tester.tap(find.byKey(const Key('horizontalBack')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detailBody')), findsNothing);
  });

  testWidgets('the reader detail scrolls its own article', (tester) async {
    await pumpPhone(tester);

    expect(find.byType(ArticleDetail), findsOneWidget);
    expect(find.byType(ArticleList), findsOneWidget);
  });

  group('in the vertical bar', () {
    testWidgets('every toolbar action reaches the app', (tester) async {
      await pumpDuo(tester);

      // Each action records what it did; running them all proves the bar
      // wired every one, including the tail that went to the overflow menu.
      for (final title in [
        'Share',
        'Bookmark',
        'Tag',
        'Flag',
        'Format',
        'Theme',
        'Enhance',
      ]) {
        final item = barItems(
          tester,
        ).firstWhere((item) => item.title == title);
        item.onPressed!();
        await tester.pumpAndSettle();
      }

      // Land on the state tab to read the last one back.
      barItems(tester).firstWhere((i) => i.title == 'State').onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('action: enhance'), findsOneWidget);
    });

    testWidgets('the bar opens the fold-aware dialog', (tester) async {
      await pumpDuo(tester);

      barItems(
        tester,
      ).firstWhere((i) => i.title == 'Fold-aware dialog').onPressed!();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('foldDialog')), findsOneWidget);
    });

    testWidgets('the bar pushes the detail page', (tester) async {
      await pumpDuo(tester);

      barItems(
        tester,
      ).firstWhere((i) => i.title == 'Open detail').onPressed!();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detailBody')), findsOneWidget);
    });

    testWidgets('the readout lists the regions the device reported', (
      tester,
    ) async {
      await pumpDuo(tester);

      barItems(tester).firstWhere((i) => i.title == 'State').onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('division 456,0 40×669'), findsOneWidget);
      expect(find.text('hinge: partiallyOpen'), findsOneWidget);
      expect(find.text('angle: 126.1°'), findsOneWidget);
      expect(find.text('corners: 0/0/84/34'), findsOneWidget);
    });

    testWidgets('the reset control clears the last action', (tester) async {
      await pumpDuo(tester);

      barItems(tester).firstWhere((i) => i.title == 'State').onPressed!();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('resetAction')));
      await tester.pumpAndSettle();

      expect(find.text('action: reset'), findsOneWidget);
    });
  });
}
