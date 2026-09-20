import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../nitro_fold_duo.native.dart';

/// What a platform without the Duo bridge reports: no fold, no hinge, no bar.
const DuoState duoStateUnavailable = DuoState(
  isSupported: false,
  hingeStatus: DuoHingeStatus.unknown,
  verticalBarEdge: DuoVerticalBarEdge.unspecified,
  hingeAngle: null,
  regions: <DuoReservedRegion>[],
);

/// Region helpers. [rect] and [margins] are in Flutter logical pixels relative
/// to the Flutter view's origin; [rect] already includes [margins].
extension DuoRegionGeometry on DuoReservedRegion {
  Rect get rect => Rect.fromLTWH(left, top, width, height);

  EdgeInsets get margins =>
      EdgeInsets.fromLTRB(marginLeft, marginTop, marginRight, marginBottom);

  /// True when the region is a horizontal band, i.e. a division here separates
  /// content into a top and a bottom area.
  bool get isHorizontalBand => width >= height;
}

extension DuoStateRegions on DuoState {
  Iterable<DuoReservedRegion> _active(DuoRegionKind kind) =>
      regions.where((r) => r.isActive && r.kind == kind);

  /// Regions that currently separate content, i.e. a partially open fold.
  Iterable<DuoReservedRegion> get activeDivisions =>
      _active(DuoRegionKind.division);

  /// Regions that can currently obscure content, e.g. a camera.
  Iterable<DuoReservedRegion> get activeOcclusions =>
      _active(DuoRegionKind.occlusion);

  DuoReservedRegion? get activeDivision =>
      activeDivisions.isEmpty ? null : activeDivisions.first;
}

/// The reserved band that actually separates a box of [size] at [origin] in
/// Flutter view coordinates, or null when no active division crosses it.
///
/// A division that misses the box, or only clips one of its edges, leaves
/// nothing on one side and so does not separate anything.
({Rect band, bool horizontal})? duoDivisionBand(
  DuoState state,
  Size size, {
  Offset origin = Offset.zero,
}) {
  for (final division in state.activeDivisions) {
    final band = division.rect.shift(-origin);
    if (division.isHorizontalBand) {
      if (band.top > 0 && band.bottom < size.height) {
        return (band: band, horizontal: true);
      }
    } else if (band.left > 0 && band.right < size.width) {
      return (band: band, horizontal: false);
    }
  }
  return null;
}

/// Padding that clears active occlusion regions out of a box of [size] at
/// [origin] in Flutter view coordinates.
///
/// Each region is cleared from the single cheapest edge it touches: a corner
/// camera only needs clearing from one side, and insetting from both would
/// throw away a whole band of the layout for nothing. A region that floats
/// inside the box touches no edge and is left to the layout, since padding
/// cannot clear it.
EdgeInsets duoOcclusionInsets(
  DuoState state,
  Size size, {
  Offset origin = Offset.zero,
}) {
  var insets = EdgeInsets.zero;
  final box = Offset.zero & size;

  for (final occlusion in state.activeOcclusions) {
    final rect = occlusion.rect.shift(-origin);
    if (!rect.overlaps(box)) continue;

    final options = <(double, EdgeInsets)>[
      if (rect.left <= 0) (rect.right, EdgeInsets.only(left: rect.right)),
      if (rect.top <= 0) (rect.bottom, EdgeInsets.only(top: rect.bottom)),
      if (rect.right >= size.width)
        (
          size.width - rect.left,
          EdgeInsets.only(right: size.width - rect.left),
        ),
      if (rect.bottom >= size.height)
        (
          size.height - rect.top,
          EdgeInsets.only(bottom: size.height - rect.top),
        ),
    ];
    if (options.isEmpty) continue;

    final pick = options.reduce((a, b) => a.$1 <= b.$1 ? a : b).$2;
    insets = EdgeInsets.fromLTRB(
      math.max(insets.left, pick.left),
      math.max(insets.top, pick.top),
      math.max(insets.right, pick.right),
      math.max(insets.bottom, pick.bottom),
    );
  }
  return insets;
}
