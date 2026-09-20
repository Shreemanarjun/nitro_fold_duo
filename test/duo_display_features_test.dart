import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

import 'duo_test_support.dart';

void main() {
  tearDown(() => debugSetDuoState(null));

  group('duoDisplayFeatures', () {
    test('nothing to publish when the device reports nothing', () {
      expect(duoDisplayFeatures(duoStateUnavailable), isEmpty);
    });

    test('a bent fold is a half-opened fold feature', () {
      final features = duoDisplayFeatures(
        duo(
          hinge: DuoHingeStatus.partiallyOpen,
          regions: [division(const Rect.fromLTWH(456, 0, 40, 669))],
        ),
      );

      expect(features, hasLength(1));
      expect(features.single.type, DisplayFeatureType.fold);
      expect(features.single.state, DisplayFeatureState.postureHalfOpened);
      expect(features.single.bounds, const Rect.fromLTWH(456, 0, 40, 669));
    });

    test('a flat fold is reported inactive and so is not published', () {
      // What the device does at 180 degrees.
      final features = duoDisplayFeatures(
        duo(
          hinge: DuoHingeStatus.fullyOpen,
          regions: [
            division(const Rect.fromLTWH(456, 0, 40, 669), isActive: false),
          ],
        ),
      );

      expect(features, isEmpty);
    });

    test('an active fold on a flat device still carries its posture', () {
      final flat = duoDisplayFeatures(
        duo(
          hinge: DuoHingeStatus.fullyOpen,
          regions: [division(const Rect.fromLTWH(456, 0, 40, 669))],
        ),
      );
      expect(flat.single.state, DisplayFeatureState.postureFlat);

      for (final status in [DuoHingeStatus.closed, DuoHingeStatus.unknown]) {
        final features = duoDisplayFeatures(
          duo(
            hinge: status,
            regions: [division(const Rect.fromLTWH(456, 0, 40, 669))],
          ),
        );
        expect(features.single.state, DisplayFeatureState.unknown);
      }
    });

    test('a camera is a cutout with no posture', () {
      final features = duoDisplayFeatures(
        duo(regions: [occlusion(const Rect.fromLTWH(867, 0, 84, 120))]),
      );

      expect(features.single.type, DisplayFeatureType.cutout);
      expect(features.single.state, DisplayFeatureState.unknown);
    });
  });

  group('DuoDisplayFeatures', () {
    testWidgets('adds the fold to what the platform already reported', (
      tester,
    ) async {
      debugSetDuoState(
        duo(regions: [division(const Rect.fromLTWH(456, 0, 40, 669))]),
      );
      late List<DisplayFeature> seen;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            displayFeatures: [
              DisplayFeature(
                bounds: Rect.fromLTWH(0, 0, 10, 10),
                type: DisplayFeatureType.cutout,
                state: DisplayFeatureState.unknown,
              ),
            ],
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: DuoDisplayFeatures(
              child: Builder(
                builder: (context) {
                  seen = MediaQuery.displayFeaturesOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      // The platform's own cutout survives alongside the Duo's fold.
      expect(seen, hasLength(2));
      expect(seen.last.type, DisplayFeatureType.fold);
    });

    testWidgets('leaves the tree untouched when there is nothing to add', (
      tester,
    ) async {
      debugSetDuoState(duoStateUnavailable);
      late List<DisplayFeature> seen;

      await tester.pumpWidget(
        host(
          child: DuoDisplayFeatures(
            child: Builder(
              builder: (context) {
                seen = MediaQuery.displayFeaturesOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(seen, isEmpty);
    });
  });
}
