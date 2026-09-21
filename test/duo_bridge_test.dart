import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

import 'duo_test_support.dart';

/// A stand-in for the native plugin, so everything that talks to the device
/// can be driven without one.
class FakeDuoBridge implements NitroFoldDuo {
  FakeDuoBridge({DuoState? initial})
    : _current = initial ?? duoStateUnavailable;

  DuoState _current;
  final _states = StreamController<DuoState>.broadcast();
  final _presses = StreamController<DuoBarPress>.broadcast();

  final capsuleUpdates =
      <({int viewId, List<String> symbols, int selected, double size})>[];
  final surfaceUpdates = <({int viewId, double radius, int tint})>[];
  final menuUpdates = <({int viewId, int button, List<String> titles})>[];

  void emit(DuoState state) {
    _current = state;
    _states.add(state);
  }

  void press(DuoBarPress press) => _presses.add(press);

  @override
  DuoState currentState() => _current;

  @override
  Stream<DuoState> get stateChanges => _states.stream;

  @override
  Stream<DuoBarPress> get glassCapsulePresses => _presses.stream;

  @override
  void updateGlassCapsule(
    int viewId,
    List<String> symbols,
    List<String> titles,
    int selectedIndex,
    int tint,
    double symbolPointSize,
    bool isDark,
  ) => capsuleUpdates.add((
    viewId: viewId,
    symbols: symbols,
    selected: selectedIndex,
    size: symbolPointSize,
  ));

  @override
  void updateGlassSurface(
    int viewId,
    double cornerRadius,
    int tint,
    bool isDark,
  ) => surfaceUpdates.add((viewId: viewId, radius: cornerRadius, tint: tint));

  @override
  void setGlassCapsuleMenu(
    int viewId,
    int buttonIndex,
    List<String> titles,
    List<String> symbols,
  ) => menuUpdates.add((viewId: viewId, button: buttonIndex, titles: titles));

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Makes `UiKitView` report a created platform view, which the framework does
/// not do on a test host.
void _mockPlatformViews(WidgetTester tester, {int viewId = 7}) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform_views,
    (call) async => call.method == 'create' ? viewId : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      null,
    ),
  );
}

void main() {
  tearDown(() {
    debugClearDuoBridge();
    debugSetDuoState(null);
  });

  group('duoBridge', () {
    test('is null where the plugin library is absent', () {
      expect(duoBridge, isNull);
    });

    test('answers the override once one is set', () {
      final fake = FakeDuoBridge();
      debugSetDuoBridge(fake);
      expect(duoBridge, same(fake));

      // An explicit null override stands for a platform with no bridge.
      debugSetDuoBridge(null);
      expect(duoBridge, isNull);

      debugClearDuoBridge();
      expect(duoBridge, isNull);
    });
  });

  group('duoState against a bridge', () {
    test('seeds from the device and follows its stream', () async {
      final fake = FakeDuoBridge(initial: duo(hinge: DuoHingeStatus.closed));
      debugSetDuoBridge(fake);
      debugSetDuoState(null);

      expect(duoState.value.hingeStatus, DuoHingeStatus.closed);

      fake.emit(duo(hinge: DuoHingeStatus.fullyOpen));
      await Future<void>.delayed(Duration.zero);

      expect(duoState.value.hingeStatus, DuoHingeStatus.fullyOpen);
    });
  });

  group('DuoGlassSurface', () {
    testWidgets('pushes its shape to the native material', (tester) async {
      final fake = FakeDuoBridge();
      debugSetDuoBridge(fake);
      _mockPlatformViews(tester);

      await tester.pumpWidget(
        host(
          child: const Center(
            child: SizedBox(
              width: 200,
              height: 70,
              child: DuoGlassSurface(
                borderRadius: 12,
                tint: Color(0xFF6750A4),
                child: Text('Fold Duo'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fake.surfaceUpdates, isNotEmpty);
      expect(fake.surfaceUpdates.last.radius, 12);
      expect(fake.surfaceUpdates.last.tint, 0xFF6750A4);
      expect(find.text('Fold Duo'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('repushes when its shape changes', (tester) async {
      final fake = FakeDuoBridge();
      debugSetDuoBridge(fake);
      _mockPlatformViews(tester);

      Widget surface(double radius) => host(
        child: Center(
          child: SizedBox(
            width: 200,
            height: 70,
            child: DuoGlassSurface(borderRadius: radius),
          ),
        ),
      );

      await tester.pumpWidget(surface(0));
      await tester.pumpAndSettle();
      await tester.pumpWidget(surface(24));
      await tester.pumpAndSettle();

      expect(fake.surfaceUpdates.last.radius, 24);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('falls back to a blur of the same shape off iOS', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          child: const Center(
            child: SizedBox(
              width: 200,
              height: 70,
              child: DuoGlassSurface(borderRadius: 12, child: Text('Fold Duo')),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('Fold Duo'), findsOneWidget);
    });

    testWidgets('does nothing without a bridge', (tester) async {
      debugSetDuoBridge(null);
      _mockPlatformViews(tester);

      await tester.pumpWidget(
        host(
          child: const Center(
            child: SizedBox(width: 200, height: 70, child: DuoGlassSurface()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DuoGlassSurface), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('bridge traffic', () {
    testWidgets('a hinge tick does not re-push an unchanged bar', (
      tester,
    ) async {
      final fake = FakeDuoBridge();
      debugSetDuoBridge(fake);
      _mockPlatformViews(tester);
      await tester.binding.setSurfaceSize(duoInnerSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      debugSetDuoState(duo(angle: 2.0));
      await tester.pumpWidget(
        host(
          child: DuoBarScaffold(
            body: const SizedBox.expand(),
            actions: const [
              DuoBarItem(symbol: 'a', title: 'A'),
              DuoBarItem(symbol: 'b', title: 'B'),
            ],
            tabs: const [
              DuoBarItem(symbol: 'c', title: 'C'),
              DuoBarItem(symbol: 'd', title: 'D'),
            ],
            selectedTab: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final afterFirstBuild = fake.capsuleUpdates.length;
      expect(afterFirstBuild, greaterThan(0));

      // The angle ticks while the device folds. Nothing about the bar changed,
      // so nothing should cross the bridge.
      for (final angle in [2.05, 2.1, 2.15, 2.2, 2.25]) {
        debugSetDuoState(duo(angle: angle));
        await tester.pumpAndSettle();
      }

      expect(fake.capsuleUpdates.length, afterFirstBuild);
      expect(duoState.value.hingeAngle, 2.25);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a real change still crosses', (tester) async {
      final fake = FakeDuoBridge();
      debugSetDuoBridge(fake);
      _mockPlatformViews(tester);

      Widget capsule(int? selected) => host(
        child: Center(
          child: SizedBox(
            width: 44,
            height: 88,
            child: DuoGlassCapsule(
              items: const [
                DuoBarItem(symbol: 'a', title: 'a'),
                DuoBarItem(symbol: 'b', title: 'b'),
              ],
              selectedIndex: selected,
            ),
          ),
        ),
      );

      await tester.pumpWidget(capsule(0));
      await tester.pumpAndSettle();
      final pushes = fake.capsuleUpdates.length;

      // Same contents, same selection: no traffic.
      await tester.pumpWidget(capsule(0));
      await tester.pumpAndSettle();
      expect(fake.capsuleUpdates.length, pushes);

      // Selection moved: one push.
      await tester.pumpWidget(capsule(1));
      await tester.pumpAndSettle();
      expect(fake.capsuleUpdates.length, pushes + 1);
      expect(fake.capsuleUpdates.last.selected, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('DuoGlassCapsule against a bridge', () {
    testWidgets('pushes its contents and menus once the view exists', (
      tester,
    ) async {
      final fake = FakeDuoBridge();
      debugSetDuoBridge(fake);
      _mockPlatformViews(tester);

      await tester.pumpWidget(
        host(
          child: Center(
            child: SizedBox(
              width: 44,
              height: 88,
              child: DuoGlassCapsule(
                items: const [
                  DuoBarItem(symbol: 'a', title: 'A'),
                  DuoBarItem(
                    symbol: 'b',
                    title: 'B',
                    menu: [DuoBarItem(symbol: 'x', title: 'Extra')],
                  ),
                ],
                selectedIndex: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fake.capsuleUpdates, isNotEmpty);
      expect(fake.capsuleUpdates.last.symbols, ['a', 'b']);
      expect(fake.capsuleUpdates.last.selected, 1);
      expect(fake.menuUpdates.last.button, 1);
      expect(fake.menuUpdates.last.titles, ['Extra']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('clears a menu that is no longer wanted', (tester) async {
      final fake = FakeDuoBridge();
      debugSetDuoBridge(fake);
      _mockPlatformViews(tester);

      Widget capsule(List<DuoBarItem> menu) => host(
        child: Center(
          child: SizedBox(
            width: 44,
            height: 44,
            child: DuoGlassCapsule(
              items: [DuoBarItem(symbol: 'a', title: 'a', menu: menu)],
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        capsule(const [DuoBarItem(symbol: 'x', title: 'x')]),
      );
      await tester.pumpAndSettle();
      expect(fake.menuUpdates.last.titles, ['x']);

      await tester.pumpWidget(capsule(const []));
      await tester.pumpAndSettle();

      expect(fake.menuUpdates.last.titles, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('routes a press and a menu choice back to the item', (
      tester,
    ) async {
      final fake = FakeDuoBridge();
      debugSetDuoBridge(fake);
      _mockPlatformViews(tester);

      final seen = <String>[];
      await tester.pumpWidget(
        host(
          child: Center(
            child: SizedBox(
              width: 44,
              height: 44,
              child: DuoGlassCapsule(
                items: [
                  DuoBarItem(
                    symbol: 'a',
                    title: 'a',
                    onPressed: () => seen.add('press'),
                    menu: [
                      const DuoBarItem(symbol: 'x', title: 'x'),
                      const DuoBarItem(symbol: 'y', title: 'y'),
                      DuoBarItem(
                        symbol: 'z',
                        title: 'z',
                        onPressed: () => seen.add('menu'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Flutter's registry assigns the id, so take it from what was pushed.
      final id = fake.capsuleUpdates.last.viewId;
      fake.press(DuoBarPress(viewId: id, index: 0, menuIndex: -1));
      fake.press(DuoBarPress(viewId: id, index: 0, menuIndex: 2));
      // Out of range, and from a capsule that is not ours: both ignored.
      fake.press(DuoBarPress(viewId: id, index: 9, menuIndex: -1));
      fake.press(DuoBarPress(viewId: id, index: 0, menuIndex: 99));
      fake.press(DuoBarPress(viewId: id + 1000, index: 0, menuIndex: -1));
      await tester.pumpAndSettle();

      expect(seen, ['press', 'menu']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('stops listening once the last capsule goes', (tester) async {
      final fake = FakeDuoBridge();
      debugSetDuoBridge(fake);
      _mockPlatformViews(tester);

      await tester.pumpWidget(
        host(
          child: const Center(
            child: SizedBox(
              width: 44,
              height: 44,
              child: DuoGlassCapsule(
                items: [DuoBarItem(symbol: 'a', title: 'a')],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(host(child: const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(fake.capsuleUpdates, isNotEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
