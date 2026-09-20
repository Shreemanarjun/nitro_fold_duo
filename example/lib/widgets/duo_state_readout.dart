import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

/// Raw state straight off the bridge — this is what proves the native query.
class DuoStateReadout extends StatelessWidget {
  const DuoStateReadout({super.key, required this.lastAction});

  final String lastAction;

  @override
  Widget build(BuildContext context) {
    return DuoBuilder(
      builder: (context, state) {
        final angle = state.hingeAngle;
        final viewPadding = MediaQuery.viewPaddingOf(context);
        final size = MediaQuery.sizeOf(context);
        return Container(
          key: const Key('readout'),
          color: Colors.deepPurple.shade50,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Duo state', style: Theme.of(context).textTheme.titleMedium),
              Text('supported: ${state.isSupported}'),
              Text('hinge: ${state.hingeStatus.name}'),
              Text(
                'angle: ${angle == null ? 'n/a' : '${(angle * 180 / math.pi).toStringAsFixed(1)}°'}',
              ),
              Text('barEdge: ${state.verticalBarEdge.name}'),
              Text(
                'barSide: ${DuoLayout.barSide(viewPadding, state: state)?.name ?? 'none'}',
                key: const Key('barSide'),
              ),
              Text('action: $lastAction', key: const Key('action')),
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
              Expanded(
                child: ListView.builder(
                  itemCount: state.regions.length,
                  itemBuilder: (context, index) {
                    final region = state.regions[index];
                    return Text(
                      '${region.kind.name}'
                      '${region.isActive ? '' : ' (inactive)'} '
                      '${region.rect.left.toStringAsFixed(0)},'
                      '${region.rect.top.toStringAsFixed(0)} '
                      '${region.rect.width.toStringAsFixed(0)}×'
                      '${region.rect.height.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
