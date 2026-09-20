import 'package:flutter/widgets.dart';

import 'package:signals_flutter/signals_flutter.dart';

import '../geometry/duo_geometry.dart';
import '../geometry/duo_local_origin.dart';
import '../geometry/duo_signals.dart';

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

class _DuoSplitState extends State<DuoSplit> with DuoLocalOrigin {
  @override
  Widget build(BuildContext context) {
    scheduleOriginSync();
    return SignalBuilder(
      builder: (context) {
        // Read the signal here, in the build phase: LayoutBuilder's callback
        // runs during layout, outside the scope SignalBuilder tracks, so a
        // read in there would never subscribe to anything.
        final state = duoState.value;
        return LayoutBuilder(
          builder: (context, constraints) {
            final split = duoDivisionBand(
              state,
              constraints.biggest,
              origin: localOrigin,
            );
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
        );
      },
    );
  }

  Widget _fallback() {
    final children = [
      Expanded(child: widget.primary),
      Expanded(child: widget.secondary),
    ];
    return switch (widget.fallbackAxis) {
      Axis.vertical => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
      Axis.horizontal => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    };
  }
}
