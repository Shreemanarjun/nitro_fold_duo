import 'package:flutter/widgets.dart';

/// Tracks a widget's origin in Flutter view coordinates so reserved regions,
/// which arrive in that space, can be resolved against its own box.
///
/// The origin is read after layout, so a widget that moves settles one frame
/// later. Fold changes are user-paced, so that is not observable in practice.
mixin DuoLocalOrigin<T extends StatefulWidget> on State<T> {
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
