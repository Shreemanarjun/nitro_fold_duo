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
  const DuoOcclusionSafeArea({super.key, required this.child});

  final Widget child;

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
          builder: (context, constraints) => Padding(
            padding: duoOcclusionInsets(
              state,
              constraints.biggest,
              origin: localOrigin,
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}
