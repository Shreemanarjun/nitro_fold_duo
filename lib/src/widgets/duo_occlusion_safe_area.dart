import 'package:flutter/widgets.dart';

import '../geometry/duo_geometry.dart';
import '../geometry/duo_local_origin.dart';
import 'duo_builder.dart';

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
