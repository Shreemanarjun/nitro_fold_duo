import 'dart:async';

import 'package:flutter/widgets.dart';

import '../geometry/duo_geometry.dart';
import '../nitro_fold_duo.native.dart';

/// Rebuilds [builder] whenever the fold geometry or hinge changes.
///
/// Region rects are in Flutter view coordinates. Use `DuoSplit` or
/// `DuoOcclusionSafeArea` when you want them resolved against your own box.
class DuoBuilder extends StatefulWidget {
  const DuoBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, DuoState state) builder;

  @override
  State<DuoBuilder> createState() => _DuoBuilderState();
}

class _DuoBuilderState extends State<DuoBuilder> {
  late DuoState _state = _initialState();
  StreamSubscription<DuoState>? _sub;

  /// The native library is absent under `flutter test` and on platforms the
  /// plugin does not build for. Duo geometry is an optional capability, so
  /// report "no Duo" rather than taking the app down with it.
  static DuoState _initialState() {
    try {
      return NitroFoldDuo.instance.currentState();
    } catch (_) {
      return duoStateUnavailable;
    }
  }

  @override
  void initState() {
    super.initState();
    try {
      _sub = NitroFoldDuo.instance.stateChanges.listen((state) {
        if (mounted) setState(() => _state = state);
      });
    } catch (_) {
      // Same as above: stay on the unavailable snapshot.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _state);
}
