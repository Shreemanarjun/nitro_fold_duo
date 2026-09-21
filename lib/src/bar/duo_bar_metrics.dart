import 'package:flutter/widgets.dart';

import '../geometry/duo_geometry.dart';
import '../nitro_fold_duo.native.dart';
import 'duo_bar_style.dart';

/// Fallback width of the vertical control strip, used only if the system
/// reports no side inset. The strip normally takes the width of that inset,
/// which is what iOS reserves for its own vertical bars and status cluster.
const double kDuoVerticalBarWidth = 60.0;

/// Space the system leaves between the controls and a free edge of the window
/// — above the first capsule and below the tab capsule.
const double kDuoBarEdgeMargin = 24.0;

/// Space the system leaves between the controls and a reserved region below.
const double kDuoBarRegionGap = 11.0;

/// Clearance below the top edge until the system has reported where the camera
/// and status cluster are. Covers the taller of the two displays, so controls
/// never start out underneath the cluster.
const double kDuoStatusClusterFallbackHeight = 170.0;

/// Space between capsules.
const double kDuoBarGroupSpacing = 12.0;

/// Width of a capsule, centred in the strip.
const double kDuoBarCapsuleWidth = 44.0;

/// Height of one icon button inside a capsule.
const double kDuoBarItemHeight = 44.0;

/// Height of the band at the top of the page that holds the title. The system
/// sets the title at the leading edge, with the controls in the strip instead
/// of beside it.
const double kDuoTitleBandHeight = 70.0;

/// Point size the system draws a bar symbol at.
const double kDuoBarSymbolPointSize = 17.0;

/// SF Symbol the system uses for an overflow menu.
const String kDuoOverflowSymbol = 'ellipsis';

/// The edge of the window the system reserves for vertical controls.
enum DuoBarSide { left, right }

/// Where iPhone Duo's vertical controls go, and how much room to leave them.
abstract final class DuoLayout {
  /// The edge the toolbar and tab bar belong on right now, or null where the
  /// system keeps bars horizontal.
  ///
  /// Decided from what the system actually reserves rather than from a device
  /// check. On iPhone Duo the window has an inset on one side only and no top
  /// inset: on the cover display, and on the inner display in landscape. It is
  /// absent elsewhere — any other iPhone in portrait has a top inset and in
  /// landscape has equal insets on both sides, an iPad has no side inset, and
  /// the Duo inner display in portrait has a top inset.
  ///
  /// Pass the *view* padding: it is known on the very first frame and, unlike
  /// `padding`, is not consumed by a [SafeArea] further up the tree. When
  /// [state] is supplied its `verticalBarEdge` vetoes the guess, since the
  /// system reports `unspecified` wherever it never places a vertical bar.
  static DuoBarSide? barSide(EdgeInsets viewPadding, {DuoState? state}) {
    if (state != null &&
        state.isSupported &&
        state.verticalBarEdge == DuoVerticalBarEdge.unspecified) {
      return null;
    }
    if (viewPadding.top != 0) return null;
    if (viewPadding.right > 0 && viewPadding.left == 0) return DuoBarSide.right;
    if (viewPadding.left > 0 && viewPadding.right == 0) return DuoBarSide.left;
    return null;
  }

  /// Width of the strip the system reserves on [barSide].
  static double stripWidth(EdgeInsets viewPadding) {
    final inset = barSide(viewPadding) == DuoBarSide.left
        ? viewPadding.left
        : viewPadding.right;
    return inset > 0 ? inset : kDuoVerticalBarWidth;
  }

  /// Free space to keep above and below the controls so they clear the camera
  /// and status cluster wherever the current rotation puts them — at the top of
  /// the strip in one rotation, at the bottom in another.
  static ({double top, double bottom}) barInsets({
    required Size size,
    required EdgeInsets viewPadding,
    required DuoState state,
    DuoBarStyle style = const DuoBarStyle(),
  }) {
    final strip = style.stripWidth ?? stripWidth(viewPadding);
    final onLeft = barSide(viewPadding) == DuoBarSide.left;
    final stripStart = onLeft ? 0.0 : size.width - strip;
    final stripEnd = onLeft ? strip : size.width;

    // Only regions that really lie in this window's strip count. While the
    // device folds or rotates, a reading taken in the previous pose can still
    // be around for a moment; its region sits elsewhere.
    final inStrip = state.activeOcclusions.where((region) {
      final rect = region.rect;
      return rect.right > stripStart &&
          rect.left < stripEnd &&
          rect.right <= size.width + 1 &&
          rect.bottom <= size.height + 1;
    }).toList();

    double? top;
    double? bottom;
    for (final region in inStrip) {
      final rect = region.rect;
      if (rect.center.dy < size.height / 2) {
        if (top == null || rect.bottom > top) top = rect.bottom;
      } else {
        final room = size.height - rect.top + kDuoBarRegionGap;
        if (bottom == null || room > bottom) bottom = room;
      }
    }

    // Every pose with a strip has the camera or the status cluster somewhere in
    // it, so an empty strip means nothing has been reported for this pose yet.
    // Until then stay clear of where the cluster can be.
    final unknown = inStrip.isEmpty;
    return (
      top:
          top ?? (unknown ? kDuoStatusClusterFallbackHeight : style.edgeMargin),
      bottom: bottom ?? style.edgeMargin,
    );
  }
}
