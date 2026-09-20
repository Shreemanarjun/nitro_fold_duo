import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

DuoReservedRegion _region(DuoRegionKind kind, Rect r, {bool isActive = true}) =>
    DuoReservedRegion(
      kind: kind,
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

DuoState _state(List<DuoReservedRegion> regions) => DuoState(
  isSupported: true,
  hingeStatus: DuoHingeStatus.partiallyOpen,
  verticalBarEdge: DuoVerticalBarEdge.trailing,
  hingeAngle: 1.5,
  regions: regions,
  cornerInsets: const DuoInsets(left: 0, top: 0, right: 0, bottom: 0),
);

const _box = Size(400, 800);

void main() {
  group('DuoRegionGeometry', () {
    test('exposes the protective margins baked into the frame', () {
      final r = _region(
        DuoRegionKind.occlusion,
        const Rect.fromLTWH(10, 20, 30, 40),
      );
      expect(r.rect, const Rect.fromLTWH(10, 20, 30, 40));
      expect(r.margins, EdgeInsets.zero);

      final padded = DuoReservedRegion(
        kind: DuoRegionKind.division,
        left: 0,
        top: 0,
        width: 10,
        height: 10,
        marginLeft: 1,
        marginTop: 2,
        marginRight: 3,
        marginBottom: 4,
        isActive: true,
      );
      expect(padded.margins, const EdgeInsets.fromLTRB(1, 2, 3, 4));
    });
  });

  group('duoDivisionBand', () {
    test('no regions does not split', () {
      expect(duoDivisionBand(_state([]), _box), isNull);
    });

    test('horizontal band splits top from bottom', () {
      final state = _state([
        _region(DuoRegionKind.division, const Rect.fromLTWH(0, 380, 400, 40)),
      ]);
      final split = duoDivisionBand(state, _box);
      expect(split, isNotNull);
      expect(split!.horizontal, isTrue);
      expect(split.band, const Rect.fromLTWH(0, 380, 400, 40));
    });

    test('vertical band splits leading from trailing', () {
      final state = _state([
        _region(DuoRegionKind.division, const Rect.fromLTWH(180, 0, 40, 800)),
      ]);
      final split = duoDivisionBand(state, _box);
      expect(split, isNotNull);
      expect(split!.horizontal, isFalse);
      expect(split.band.left, 180);
    });

    test('inactive division is ignored', () {
      final state = _state([
        _region(
          DuoRegionKind.division,
          const Rect.fromLTWH(0, 380, 400, 40),
          isActive: false,
        ),
      ]);
      expect(duoDivisionBand(state, _box), isNull);
    });

    test('occlusion is never treated as a division', () {
      final state = _state([
        _region(DuoRegionKind.occlusion, const Rect.fromLTWH(0, 380, 400, 40)),
      ]);
      expect(duoDivisionBand(state, _box), isNull);
    });

    test('band that misses the box does not split', () {
      final state = _state([
        _region(DuoRegionKind.division, const Rect.fromLTWH(0, 900, 400, 40)),
      ]);
      expect(duoDivisionBand(state, _box), isNull);
    });

    test('band that only clips an edge leaves nothing on one side', () {
      final state = _state([
        _region(DuoRegionKind.division, const Rect.fromLTWH(0, -10, 400, 40)),
      ]);
      expect(duoDivisionBand(state, _box), isNull);
    });

    test('origin translates the band into the local box', () {
      // Division at global y 380..420; a box starting at global y 300 sees it
      // at local y 80..120 and is split by it.
      final state = _state([
        _region(DuoRegionKind.division, const Rect.fromLTWH(0, 380, 400, 40)),
      ]);
      final split = duoDivisionBand(
        state,
        const Size(400, 500),
        origin: const Offset(0, 300),
      );
      expect(split, isNotNull);
      expect(split!.band.top, 80);

      // The same division misses a box that starts below it.
      expect(
        duoDivisionBand(
          state,
          const Size(400, 500),
          origin: const Offset(0, 500),
        ),
        isNull,
      );
    });
  });

  group('duoOcclusionInsets', () {
    test('no regions means no padding', () {
      expect(duoOcclusionInsets(_state([]), _box), EdgeInsets.zero);
    });

    test('corner region is cleared from its cheapest edge only', () {
      // Touches the top (cost 170) and the right (cost 84) — take the right.
      final state = _state([
        _region(DuoRegionKind.occlusion, const Rect.fromLTWH(316, 0, 84, 170)),
      ]);
      expect(
        duoOcclusionInsets(state, _box),
        const EdgeInsets.only(right: 84),
      );
    });

    test('regions on opposite edges both apply', () {
      final state = _state([
        _region(DuoRegionKind.occlusion, const Rect.fromLTWH(0, 0, 400, 30)),
        _region(DuoRegionKind.occlusion, const Rect.fromLTWH(0, 760, 400, 40)),
      ]);
      expect(
        duoOcclusionInsets(state, _box),
        const EdgeInsets.only(top: 30, bottom: 40),
      );
    });

    test('the deepest region on an edge wins', () {
      final state = _state([
        _region(DuoRegionKind.occlusion, const Rect.fromLTWH(0, 0, 400, 30)),
        _region(DuoRegionKind.occlusion, const Rect.fromLTWH(0, 0, 400, 50)),
      ]);
      expect(duoOcclusionInsets(state, _box), const EdgeInsets.only(top: 50));
    });

    test('a region floating inside the box cannot be padded away', () {
      final state = _state([
        _region(DuoRegionKind.occlusion, const Rect.fromLTWH(180, 380, 40, 40)),
      ]);
      expect(duoOcclusionInsets(state, _box), EdgeInsets.zero);
    });

    test('a region outside the box is ignored', () {
      final state = _state([
        _region(DuoRegionKind.occlusion, const Rect.fromLTWH(0, 900, 400, 40)),
      ]);
      expect(duoOcclusionInsets(state, _box), EdgeInsets.zero);
    });

    test('inactive region is ignored', () {
      final state = _state([
        _region(
          DuoRegionKind.occlusion,
          const Rect.fromLTWH(0, 0, 400, 30),
          isActive: false,
        ),
      ]);
      expect(duoOcclusionInsets(state, _box), EdgeInsets.zero);
    });

    test('origin translates the region into the local box', () {
      // Global region 0..30 is above a box that starts at global y 100, so it
      // no longer touches that box at all.
      final state = _state([
        _region(DuoRegionKind.occlusion, const Rect.fromLTWH(0, 0, 400, 30)),
      ]);
      expect(
        duoOcclusionInsets(state, _box, origin: const Offset(0, 100)),
        EdgeInsets.zero,
      );
    });
  });
}
