import 'package:flutter/widgets.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

/// The inner display in landscape, as measured on the iPhone Duo simulator.
const duoInnerSize = Size(951, 669);
const duoInnerViewPadding = EdgeInsets.only(right: 84, bottom: 34);

/// The cover display.
const duoCoverSize = Size(466, 678);

/// Any other iPhone in portrait: a top inset, so bars stay horizontal.
const phoneViewPadding = EdgeInsets.only(top: 59, bottom: 34);

DuoReservedRegion region(
  DuoRegionKind kind,
  Rect r, {
  bool isActive = true,
  EdgeInsets margins = EdgeInsets.zero,
}) => DuoReservedRegion(
  kind: kind,
  left: r.left,
  top: r.top,
  width: r.width,
  height: r.height,
  marginLeft: margins.left,
  marginTop: margins.top,
  marginRight: margins.right,
  marginBottom: margins.bottom,
  isActive: isActive,
);

DuoReservedRegion occlusion(Rect r, {bool isActive = true}) =>
    region(DuoRegionKind.occlusion, r, isActive: isActive);

DuoReservedRegion division(Rect r, {bool isActive = true}) =>
    region(DuoRegionKind.division, r, isActive: isActive);

DuoState duo({
  List<DuoReservedRegion> regions = const [],
  DuoVerticalBarEdge edge = DuoVerticalBarEdge.trailing,
  DuoHingeStatus hinge = DuoHingeStatus.partiallyOpen,
  double? angle = 2.2,
  bool isSupported = true,
  DuoInsets cornerInsets = const DuoInsets(
    left: 0,
    top: 0,
    right: 0,
    bottom: 0,
  ),
}) => DuoState(
  isSupported: isSupported,
  hingeStatus: hinge,
  verticalBarEdge: edge,
  hingeAngle: angle,
  regions: regions,
  cornerInsets: cornerInsets,
);

/// Wraps [child] in the media query a Duo pose produces.
Widget host({
  required Widget child,
  Size size = duoInnerSize,
  EdgeInsets viewPadding = duoInnerViewPadding,
  TextDirection textDirection = TextDirection.ltr,
}) => MediaQuery(
  data: MediaQueryData(
    size: size,
    viewPadding: viewPadding,
    padding: viewPadding,
  ),
  child: Directionality(textDirection: textDirection, child: child),
);
