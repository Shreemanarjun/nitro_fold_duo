import 'package:flutter/material.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NitroFoldDuo Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
      home: const _DemoPage(),
    );
  }
}

class _DemoPage extends StatelessWidget {
  const _DemoPage();

  @override
  Widget build(BuildContext context) {
    // Read the system padding here, above SafeArea, so the readout shows what
    // iOS actually reserves rather than what SafeArea has already consumed.
    final systemPadding = MediaQuery.paddingOf(context);
    return Scaffold(
      // One avoidance layer only: DuoOcclusionSafeArea already clears the
      // camera, and nesting it in a SafeArea would inset twice for it.
      body: DuoOcclusionSafeArea(
        child: DuoSplit(
          primary: _Readout(systemPadding: systemPadding),
          secondary: const _Controls(),
        ),
      ),
    );
  }
}

/// Raw state straight off the bridge — this is what proves the native query.
class _Readout extends StatelessWidget {
  const _Readout({required this.systemPadding});

  final EdgeInsets systemPadding;

  @override
  Widget build(BuildContext context) {
    return DuoBuilder(
      builder: (context, state) {
        final angle = state.hingeAngle;
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
                'angle: ${angle == null ? 'n/a' : '${(angle * 180 / 3.141592653589793).toStringAsFixed(1)}°'}',
              ),
              Text('regions: ${state.regions.length}'),
              Builder(
                builder: (context) {
                  final media = MediaQuery.of(context);
                  return Text(
                    'screen: ${media.size.width.toStringAsFixed(0)}'
                    '×${media.size.height.toStringAsFixed(0)} '
                    'safeArea ${systemPadding.left.toStringAsFixed(0)}/'
                    '${systemPadding.top.toStringAsFixed(0)}/'
                    '${systemPadding.right.toStringAsFixed(0)}/'
                    '${systemPadding.bottom.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12),
                  );
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
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
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Stand-in for fixed controls: the half that should move off the fold.
class _Controls extends StatefulWidget {
  const _Controls();

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  String _result = '—';

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('controls'),
      color: Colors.teal.shade50,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_result, key: const Key('result')),
          const SizedBox(height: 12),
          ElevatedButton(
            key: const Key('addButton'),
            onPressed: () => setState(
              () => _result = 'add(3, 4) = ${NitroFoldDuo.instance.add(3, 4)}',
            ),
            child: const Text('add(3, 4)'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            key: const Key('snapshotButton'),
            onPressed: () {
              final state = NitroFoldDuo.instance.currentState();
              setState(
                () => _result =
                    'currentState(): ${state.regions.length} regions, '
                    '${state.hingeStatus.name}',
              );
            },
            child: const Text('currentState()'),
          ),
        ],
      ),
    );
  }
}
