import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

import 'duo_test_support.dart';

const _primary = Key('primary');
const _secondary = Key('secondary');
const _child = Key('child');

Widget _split({Axis fallbackAxis = Axis.vertical}) => DuoSplit(
  fallbackAxis: fallbackAxis,
  primary: const ColoredBox(key: _primary, color: Color(0xFF000000)),
  secondary: const ColoredBox(key: _secondary, color: Color(0xFFFFFFFF)),
);

void main() {
  tearDown(() => debugSetDuoState(null));

  group('DuoSplit', () {
    testWidgets('puts the panes either side of a horizontal fold', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugSetDuoState(
        duo(regions: [division(const Rect.fromLTWH(0, 380, 400, 40))]),
      );

      await tester.pumpWidget(
        host(child: _split(), size: const Size(400, 800)),
      );

      // The band itself stays empty: 380 above it, 380 below, 40 reserved.
      expect(tester.getSize(find.byKey(_primary)).height, 380);
      expect(tester.getSize(find.byKey(_secondary)).height, 380);
      expect(tester.getTopLeft(find.byKey(_secondary)).dy, 420);
    });

    testWidgets('puts the panes either side of a vertical fold', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugSetDuoState(
        duo(regions: [division(const Rect.fromLTWH(180, 0, 40, 800))]),
      );

      await tester.pumpWidget(
        host(child: _split(), size: const Size(400, 800)),
      );

      expect(tester.getSize(find.byKey(_primary)).width, 180);
      expect(tester.getTopLeft(find.byKey(_secondary)).dx, 220);
    });

    testWidgets('shares the box along the fallback axis with no fold', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugSetDuoState(duo(hinge: DuoHingeStatus.closed));

      await tester.pumpWidget(
        host(child: _split(), size: const Size(400, 800)),
      );
      expect(tester.getSize(find.byKey(_primary)).height, 400);

      await tester.pumpWidget(
        host(
          child: _split(fallbackAxis: Axis.horizontal),
          size: const Size(400, 800),
        ),
      );
      expect(tester.getSize(find.byKey(_primary)).width, 200);
    });

    testWidgets('re-splits when the device folds', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugSetDuoState(duo(hinge: DuoHingeStatus.closed));

      await tester.pumpWidget(
        host(child: _split(), size: const Size(400, 800)),
      );
      expect(tester.getSize(find.byKey(_primary)).height, 400);

      debugSetDuoState(
        duo(regions: [division(const Rect.fromLTWH(0, 380, 400, 40))]),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byKey(_primary)).height, 380);
    });

    testWidgets('resolves the fold against its own box, not the window', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // A fold at global y 380..420, under a 200pt header: locally 180..220.
      debugSetDuoState(
        duo(regions: [division(const Rect.fromLTWH(0, 380, 400, 40))]),
      );

      await tester.pumpWidget(
        host(
          size: const Size(400, 800),
          child: Column(
            children: [
              const SizedBox(height: 200, child: ColoredBox(color: Color(0xFF000000))),
              Expanded(child: _split()),
            ],
          ),
        ),
      );
      // The origin is read after layout, so the split settles a frame later.
      await tester.pump();

      expect(tester.getSize(find.byKey(_primary)).height, 180);
    });
  });

  group('DuoOcclusionSafeArea', () {
    testWidgets('clears an occlusion from the cheapest edge', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Touches top (cost 170) and right (cost 84): the right edge wins.
      debugSetDuoState(
        duo(regions: [occlusion(const Rect.fromLTWH(316, 0, 84, 170))]),
      );

      await tester.pumpWidget(
        host(
          size: const Size(400, 800),
          child: const DuoOcclusionSafeArea(
            child: ColoredBox(key: _child, color: Color(0xFF000000)),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(_child)).width, 400 - 84);
    });

    testWidgets('leaves the child alone when nothing is occluded', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      debugSetDuoState(duo());

      await tester.pumpWidget(
        host(
          size: const Size(400, 800),
          child: DuoOcclusionSafeArea(
            child: const ColoredBox(key: _child, color: Color(0xFF000000)),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(_child)), const Size(400, 800));
    });
  });
}
