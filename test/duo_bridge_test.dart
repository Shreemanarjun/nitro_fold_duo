import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

import 'duo_test_support.dart';

/// A stand-in for the native plugin, so everything that talks to the device
/// can be driven without one.
class FakeDuoBridge implements NitroFoldDuo {
  FakeDuoBridge({DuoState? initial}) : _current = initial ?? duoStateUnavailable;

  DuoState _current;
  final _states = StreamController<DuoState>.broadcast();
  final _presses = StreamController<DuoBarPress>.broadcast();

  final capsuleUpdates = <({int viewId, List<String> symbols, int selected})>[];
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
    bool isDark,
  ) => capsuleUpdates.add((
    viewId: viewId,
    symbols: symbols,
    selected: selectedIndex,
  ));

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
                symbols: const ['a', 'b'],
                titles: const ['A', 'B'],
                selectedIndex: 1,
                menus: {
                  1: const [DuoBarItem(symbol: 'x', title: 'Extra')],
                },
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

      Widget capsule(Map<int, List<DuoBarItem>> menus) => host(
        child: Center(
          child: SizedBox(
            width: 44,
            height: 44,
            child: DuoGlassCapsule(symbols: const ['a'], menus: menus),
          ),
        ),
      );

      await tester.pumpWidget(
        capsule({
          0: const [DuoBarItem(symbol: 'x')],
        }),
      );
      await tester.pumpAndSettle();
      expect(fake.menuUpdates.last.titles, ['x']);

      await tester.pumpWidget(capsule(const {}));
      await tester.pumpAndSettle();

      expect(fake.menuUpdates.last.titles, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('routes a press and a menu choice back to the item', (
      tester,
    ) async {
      final fake = FakeDuoBridge();
      debugSetDuoBridge(fake);
      _mockPlatformViews(tester);

      final seen = <(int, int)>[];
      await tester.pumpWidget(
        host(
          child: Center(
            child: SizedBox(
              width: 44,
              height: 44,
              child: DuoGlassCapsule(
                symbols: const ['a'],
                onPressed: (index, menuIndex) => seen.add((index, menuIndex)),
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
      // A press from a capsule that is not ours must be ignored.
      fake.press(DuoBarPress(viewId: id + 1000, index: 0, menuIndex: -1));
      await tester.pumpAndSettle();

      expect(seen, [(0, -1), (0, 2)]);
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
              child: DuoGlassCapsule(symbols: ['a']),
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
