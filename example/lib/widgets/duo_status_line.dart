import 'package:flutter/material.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

/// One line of what the device is doing right now, under whatever the app is
/// showing.
///
/// Handy in the demo — you can watch the fold while reading — and it means the
/// pose harness can read the state without caring which tab is up.
class DuoStatusLine extends StatelessWidget {
  const DuoStatusLine({super.key});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final state = duoState.value;
        final size = MediaQuery.sizeOf(context);
        final viewPadding = MediaQuery.viewPaddingOf(context);
        final division = duoActiveDivision.value;

        return Container(
          key: const Key('statusLine'),
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          // The strip replaces the bars but not the home indicator, and
          // nothing above this pads for it. The background runs under it —
          // the system allows that — while the text stays clear.
          padding: EdgeInsets.fromLTRB(12, 6, 12, 6 + viewPadding.bottom),
          child: Text(
            'hinge: ${state.hingeStatus.name} · '
            'screen: ${size.width.toStringAsFixed(0)}'
            '×${size.height.toStringAsFixed(0)} · '
            'viewPad ${viewPadding.left.toStringAsFixed(0)}/'
            '${viewPadding.top.toStringAsFixed(0)}/'
            '${viewPadding.right.toStringAsFixed(0)}/'
            '${viewPadding.bottom.toStringAsFixed(0)} · '
            '${division == null ? 'no division' : 'division '
                      '${division.rect.left.toStringAsFixed(0)},'
                      '${division.rect.top.toStringAsFixed(0)} '
                      '${division.rect.width.toStringAsFixed(0)}×'
                      '${division.rect.height.toStringAsFixed(0)}'}',
            style: const TextStyle(fontSize: 11),
          ),
        );
      },
    );
  }
}
