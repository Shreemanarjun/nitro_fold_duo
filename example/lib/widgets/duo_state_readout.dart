import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

/// Raw state straight off the bridge — this is what proves the native query.
class DuoStateReadout extends StatelessWidget {
  const DuoStateReadout({
    super.key,
    required this.lastAction,
    required this.onReset,
  });

  final String lastAction;

  /// A Flutter-drawn control in the body, next to the native ones in the
  /// strip: it tells a failing bar interaction apart from a failing bridge.
  final VoidCallback onReset;

  String _insets(DuoInsets insets) =>
      '${insets.left.toStringAsFixed(0)}/${insets.top.toStringAsFixed(0)}/'
      '${insets.right.toStringAsFixed(0)}/${insets.bottom.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    // The signals way: read what you need, rebuild when it changes.
    return SignalBuilder(
      builder: (context) {
        final state = duoState.value;
        final angle = state.hingeAngle;
        final viewPadding = MediaQuery.viewPaddingOf(context);
        final size = MediaQuery.sizeOf(context);
        final side = DuoLayout.barSide(viewPadding, state: state);

        return Container(
          key: const Key('readout'),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.all(12),
          child: ListView(
            children: [
              Text('Duo state', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('supported: ${state.isSupported}'),
              // A narrower signal: this line does not rebuild when a camera
              // region moves, only when the fold status itself changes.
              SignalBuilder(
                builder: (context) =>
                    Text('hinge: ${duoHingeStatus.value.name}'),
              ),
              Text(
                'angle: ${angle == null ? 'n/a' : '${(angle * 180 / math.pi).toStringAsFixed(1)}°'}',
              ),
              Text('barEdge: ${state.verticalBarEdge.name}'),
              Text('barSide: ${side?.name ?? 'none'}', key: const Key('barSide')),
              Text('corners: ${_insets(state.cornerInsets)}'),
              Text(
                'screen: ${size.width.toStringAsFixed(0)}'
                '×${size.height.toStringAsFixed(0)} '
                'viewPad ${viewPadding.left.toStringAsFixed(0)}/'
                '${viewPadding.top.toStringAsFixed(0)}/'
                '${viewPadding.right.toStringAsFixed(0)}/'
                '${viewPadding.bottom.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              // Wraps rather than overflowing: the strip leaves this pane
              // narrow, and the action text grows with whatever was pressed.
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text('action: $lastAction', key: const Key('action')),
                  TextButton(
                    key: const Key('resetAction'),
                    onPressed: onReset,
                    child: const Text('reset'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final region in state.regions)
                Text(
                  '${region.kind.name}'
                  '${region.isActive ? '' : ' (inactive)'} '
                  '${region.rect.left.toStringAsFixed(0)},'
                  '${region.rect.top.toStringAsFixed(0)} '
                  '${region.rect.width.toStringAsFixed(0)}×'
                  '${region.rect.height.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        );
      },
    );
  }
}
