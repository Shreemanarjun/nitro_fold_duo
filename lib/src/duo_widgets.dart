import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'nitro_fold_duo.native.dart';

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
        (size.width - rect.left, EdgeInsets.only(right: size.width - rect.left)),
      if (rect.bottom >= size.height)
        (size.height - rect.top, EdgeInsets.only(bottom: size.height - rect.top)),
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

/// Rebuilds [builder] whenever the fold geometry or hinge changes.
///
/// Region rects are in Flutter view coordinates. Use [DuoSplit] or
/// [DuoOcclusionSafeArea] when you want them resolved against your own box.
class DuoBuilder extends StatefulWidget {
  const DuoBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, DuoState state) builder;

  @override
  State<DuoBuilder> createState() => _DuoBuilderState();
}

class _DuoBuilderState extends State<DuoBuilder> {
  late DuoState _state = NitroFoldDuo.instance.currentState();
  StreamSubscription<DuoState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = NitroFoldDuo.instance.stateChanges.listen((state) {
      if (mounted) setState(() => _state = state);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _state);
}

/// Tracks this widget's origin in Flutter view coordinates so reserved regions
/// can be resolved against its own box.
///
/// The origin is read after layout, so a widget that moves settles one frame
/// later. Fold changes are user-paced, so that is not observable in practice.
mixin _LocalOrigin<T extends StatefulWidget> on State<T> {
  Offset localOrigin = Offset.zero;

  void scheduleOriginSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final origin = box.localToGlobal(Offset.zero);
      if (origin != localOrigin) setState(() => localOrigin = origin);
    });
  }
}

/// Places [primary] and [secondary] on opposite sides of an active fold,
/// leaving the reserved band itself empty.
///
/// With no active division crossing this box the children share it along
/// [fallbackAxis] instead — so this is also the non-folded layout, not
/// something to swap in when the phone bends.
///
/// Keep continuously scrolling content out of this: a feed or article should
/// stay stable through the curved region rather than jump to another pane.
class DuoSplit extends StatefulWidget {
  const DuoSplit({
    super.key,
    required this.primary,
    required this.secondary,
    this.fallbackAxis = Axis.vertical,
  });

  final Widget primary;
  final Widget secondary;

  /// How the two children share the box when no division applies.
  final Axis fallbackAxis;

  @override
  State<DuoSplit> createState() => _DuoSplitState();
}

class _DuoSplitState extends State<DuoSplit> with _LocalOrigin {
  @override
  Widget build(BuildContext context) {
    scheduleOriginSync();
    return DuoBuilder(
      builder: (context, state) => LayoutBuilder(
        builder: (context, constraints) {
          final split =
              duoDivisionBand(state, constraints.biggest, origin: localOrigin);
          if (split == null) return _fallback();
          return split.horizontal
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: split.band.top, child: widget.primary),
                    SizedBox(height: split.band.height),
                    Expanded(child: widget.secondary),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: split.band.left, child: widget.primary),
                    SizedBox(width: split.band.width),
                    Expanded(child: widget.secondary),
                  ],
                );
        },
      ),
    );
  }

  Widget _fallback() {
    final children = [
      Expanded(child: widget.primary),
      Expanded(child: widget.secondary),
    ];
    return widget.fallbackAxis == Axis.vertical
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// Insets [child] so it clears active occlusion regions, such as the camera.
///
/// iOS already folds some of this into the safe area, so nesting this inside a
/// [SafeArea] can inset twice for the same camera. Use one or the other per
/// box unless you have checked both are needed.
class DuoOcclusionSafeArea extends StatefulWidget {
  const DuoOcclusionSafeArea({super.key, required this.child});

  final Widget child;

  @override
  State<DuoOcclusionSafeArea> createState() => _DuoOcclusionSafeAreaState();
}

class _DuoOcclusionSafeAreaState extends State<DuoOcclusionSafeArea>
    with _LocalOrigin {
  @override
  Widget build(BuildContext context) {
    scheduleOriginSync();
    return DuoBuilder(
      builder: (context, state) => LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: duoOcclusionInsets(
            state,
            constraints.biggest,
            origin: localOrigin,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
