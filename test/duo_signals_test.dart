import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

import 'duo_test_support.dart';

void main() {
  tearDown(() => debugSetDuoState(null));

  group('duoState', () {
    test('reports no Duo when the native bridge is unavailable', () {
      // There is no plugin library under `flutter test`, so the signal must
      // fall back rather than throw.
      expect(duoState.value, duoStateUnavailable);
      expect(duoState.value.isSupported, isFalse);
      expect(duoState.value.regions, isEmpty);
    });

    test('is the same signal every read', () {
      expect(identical(duoState, duoState), isTrue);
    });

    test('debugSetDuoState publishes a staged device', () {
      final staged = duo(hinge: DuoHingeStatus.fullyOpen);
      debugSetDuoState(staged);

      expect(duoState.value, same(staged));
    });

    test('debugSetDuoState(null) drops back to the device', () {
      debugSetDuoState(duo(hinge: DuoHingeStatus.closed));
      debugSetDuoState(null);

      expect(duoState.value, duoStateUnavailable);
    });
  });

  group('derived signals', () {
    test('follow the state they are computed from', () {
      debugSetDuoState(
        duo(
          hinge: DuoHingeStatus.partiallyOpen,
          edge: DuoVerticalBarEdge.leading,
          regions: [
            division(const Rect.fromLTWH(0, 380, 400, 40)),
            occlusion(const Rect.fromLTWH(0, 0, 400, 30)),
          ],
        ),
      );

      expect(duoHingeStatus.value, DuoHingeStatus.partiallyOpen);
      expect(duoVerticalBarEdge.value, DuoVerticalBarEdge.leading);
      expect(duoActiveDivision.value?.rect.top, 380);
      expect(duoActiveOcclusions.value, hasLength(1));
    });

    test('report no fold when the device is flat', () {
      // A flat fold is reported inactive, as the device does at 180 degrees.
      debugSetDuoState(
        duo(
          hinge: DuoHingeStatus.fullyOpen,
          regions: [
            division(const Rect.fromLTWH(0, 380, 400, 40), isActive: false),
          ],
        ),
      );

      expect(duoActiveDivision.value, isNull);
      expect(duoHingeStatus.value, DuoHingeStatus.fullyOpen);
    });

    test('recompute when the device changes', () {
      debugSetDuoState(duo(hinge: DuoHingeStatus.closed));
      expect(duoHingeStatus.value, DuoHingeStatus.closed);

      debugSetDuoState(duo(hinge: DuoHingeStatus.fullyOpen));
      expect(duoHingeStatus.value, DuoHingeStatus.fullyOpen);
    });
  });

  group('corner insets', () {
    test('are zero where the system reports no rounded corners', () {
      expect(duoCornerInsets.value, EdgeInsets.zero);
      expect(duoStateUnavailable.cornerInsets.edgeInsets, EdgeInsets.zero);
    });

    test('carry what the display curve eats into each edge', () {
      // What an iPhone Duo reports on the cover display: a corner inset on the
      // leading edge that the ordinary safe area says nothing about.
      debugSetDuoState(
        duo(
          cornerInsets: const DuoInsets(left: 16, top: 0, right: 84, bottom: 34),
        ),
      );

      expect(
        duoCornerInsets.value,
        const EdgeInsets.fromLTRB(16, 0, 84, 34),
      );
    });
  });

  group('DuoBuilder', () {
    testWidgets('builds with the current state and rebuilds on change', (
      tester,
    ) async {
      debugSetDuoState(duo(hinge: DuoHingeStatus.closed));

      await tester.pumpWidget(
        host(
          child: DuoBuilder(
            builder: (context, state) => Text(state.hingeStatus.name),
          ),
        ),
      );
      expect(find.text('closed'), findsOneWidget);

      debugSetDuoState(duo(hinge: DuoHingeStatus.fullyOpen));
      await tester.pump();

      expect(find.text('fullyOpen'), findsOneWidget);
    });
  });
}
