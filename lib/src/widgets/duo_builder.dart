import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../geometry/duo_signals.dart';
import '../nitro_fold_duo.native.dart';

/// Rebuilds [builder] whenever the fold geometry or hinge changes.
///
/// A convenience over [duoState] for code that wants the whole snapshot:
///
/// ```dart
/// DuoBuilder(builder: (context, state) => Text(state.hingeStatus.name))
/// ```
///
/// Reach for [SignalBuilder] and the narrower signals — [duoActiveDivision],
/// [duoHingeStatus] — when you only care about part of the state and would
/// rather not rebuild for the rest.
///
/// Region rects are in Flutter view coordinates. Use `DuoSplit` or
/// `DuoOcclusionSafeArea` when you want them resolved against your own box.
class DuoBuilder extends StatelessWidget {
  const DuoBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, DuoState state) builder;

  @override
  Widget build(BuildContext context) =>
      SignalBuilder(builder: (context) => builder(context, duoState.value));
}
