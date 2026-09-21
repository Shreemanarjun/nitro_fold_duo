import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:signals_flutter/signals_flutter.dart';

import '../geometry/duo_geometry.dart';
import '../geometry/duo_local_origin.dart';
import '../geometry/duo_signals.dart';

/// Insets [child] so it clears active occlusion regions, such as the camera.
///
/// iOS already folds some of this into the safe area, so nesting this inside a
/// [SafeArea] can inset twice for the same camera. Use one or the other per
/// box unless you have checked both are needed.
class DuoOcclusionSafeArea extends StatefulWidget {
  const DuoOcclusionSafeArea({
    super.key,
    required this.child,
    this.minimum = EdgeInsets.zero,
  });

  final Widget child;

  /// A floor under the computed insets, for a layout that wants breathing room
  /// at an edge whether or not a camera is there.
  final EdgeInsets minimum;

  @override
  State<DuoOcclusionSafeArea> createState() => _DuoOcclusionSafeAreaState();
}

class _DuoOcclusionSafeAreaState extends State<DuoOcclusionSafeArea>
    with DuoLocalOrigin {
  @override
  Widget build(BuildContext context) {
    scheduleOriginSync();
    return SignalBuilder(
      builder: (context) {
        // Read the signal here, in the build phase: LayoutBuilder's callback
        // runs during layout, outside the scope SignalBuilder tracks.
        final state = duoState.value;
        return LayoutBuilder(
          builder: (context, constraints) {
            final insets = duoOcclusionInsets(
              state,
              constraints.biggest,
              origin: localOrigin,
            );
            final minimum = widget.minimum;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                math.max(insets.left, minimum.left),
                math.max(insets.top, minimum.top),
                math.max(insets.right, minimum.right),
                math.max(insets.bottom, minimum.bottom),
              ),
              child: widget.child,
            );
          },
        );
      },
    );
  }
}
