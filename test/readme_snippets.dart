// Compile check for the examples in README.md. Not a test: `flutter test`
// ignores it, `flutter analyze` does not. Keep the two in step — an example
// that no longer compiles is worse than no example.
//
// ignore_for_file: unused_element, unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

// App-side pieces the README refers to by name.
class ArticleList extends StatelessWidget {
  const ArticleList({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class ArticleDetail extends StatelessWidget {
  const ArticleDetail({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void share() {}
void save() {}
void settings() {}
void edit() {}
void delete() {}
void pop() {}
void go(int index) {}

const body = SizedBox();
const myTabBar = SizedBox();
const tab = 0;
const items = <DuoBarItem>[];
const actions = <DuoBarItem>[];
const tabs = <DuoBarItem>[];

// --- intro -----------------------------------------------------------------

Widget _intro() =>
    SignalBuilder(builder: (context) => Text(duoState.value.hingeStatus.name));

// --- getting started -------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (context, child) => DuoDisplayFeatures(child: child!),
    home: const HomePage(),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => DuoBarScaffold(
    title: const Text('Library'),
    actions: [
      DuoBarItem(
        symbol: 'square.and.arrow.up',
        title: 'Share',
        onPressed: () {},
      ),
      DuoBarItem(symbol: 'gearshape', title: 'Settings', onPressed: () {}),
    ],
    horizontalChrome: (context, body) => Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: body,
    ),
    body: const Center(child: Text('Content')),
  );
}

// --- state -----------------------------------------------------------------

Widget _state() => SignalBuilder(
  builder: (context) {
    final state = duoState.value;
    return Text('${state.hingeStatus.name} · ${state.regions.length} regions');
  },
);

Widget _derived() =>
    SignalBuilder(builder: (context) => Text(duoHingeStatus.value.name));

// --- widgets ---------------------------------------------------------------

Widget _builder() => DuoBuilder(
  builder: (context, state) =>
      Text(state.isSupported ? state.hingeStatus.name : 'not a foldable'),
);

Widget _split() => DuoSplit(
  primary: const ArticleList(),
  secondary: const ArticleDetail(),
  fallbackAxis: Axis.horizontal,
  band: const ColoredBox(color: Color(0x14000000)),
);

Widget _occlusion() => DuoOcclusionSafeArea(
  minimum: const EdgeInsets.all(8),
  child: const Text('Never under the camera'),
);

Widget _displayFeatures() => MaterialApp(
  builder: (context, child) => DuoDisplayFeatures(child: child!),
  home: const HomePage(),
);

void _mapping() {
  final features = duoDisplayFeatures(duoState.value);
  debugPrint('${features.length}');
}

Widget _scaffold(BuildContext context) => DuoBarScaffold(
  title: const Text('Library'),
  leading: DuoBarItem(
    symbol: 'chevron.backward',
    title: 'Back',
    onPressed: () => Navigator.of(context).pop(),
  ),
  actions: [
    DuoBarItem(symbol: 'square.and.arrow.up', title: 'Share', onPressed: share),
    DuoBarItem(
      symbol: 'bookmark',
      title: 'Save',
      onPressed: save,
      endsGroup: true,
    ),
    DuoBarItem(symbol: 'gearshape', title: 'Settings', onPressed: settings),
  ],
  tabs: [
    DuoBarItem(symbol: 'text.justify', title: 'Read', onPressed: () => go(0)),
    DuoBarItem(symbol: 'info.circle', title: 'State', onPressed: () => go(1)),
  ],
  selectedTab: tab,
  horizontalChrome: (context, body) => Scaffold(
    appBar: AppBar(title: const Text('Library')),
    bottomNavigationBar: myTabBar,
    body: body,
  ),
  body: body,
);

DuoBarItem _item() => DuoBarItem(
  symbol: 'ellipsis',
  title: 'More',
  menu: [
    DuoBarItem(symbol: 'pencil', title: 'Edit', onPressed: edit),
    DuoBarItem(symbol: 'trash', title: 'Delete', onPressed: delete),
  ],
);

Widget _verticalBar() => Row(
  children: [
    Expanded(child: body),
    DuoBuilder(
      builder: (context, state) => DuoVerticalBar(
        state: state,
        leading: DuoBarItem(
          symbol: 'chevron.backward',
          title: 'Back',
          onPressed: pop,
        ),
        actions: actions,
        tabs: tabs,
        selectedTab: tab,
      ),
    ),
  ],
);

Widget _capsule() => SizedBox(
  width: 52,
  height: 44.0 * items.length,
  child: DuoGlassCapsule(
    items: items,
    selectedIndex: 1,
    tint: const Color(0xFF6750A4),
    symbolPointSize: 20,
  ),
);

Widget _surface() => DuoGlassSurface(
  borderRadius: 16,
  tint: const Color(0x226750A4),
  child: const Padding(padding: EdgeInsets.all(12), child: Text('Library')),
);

// --- styling ---------------------------------------------------------------

Widget _theme() => DuoBarTheme(
  style: const DuoBarStyle(
    capsuleWidth: 52,
    symbolPointSize: 20,
    tint: Color(0xFF6750A4),
    titleBackdropRadius: 16,
  ),
  child: const DuoBarScaffold(body: body),
);

Widget _styleOverride(BuildContext context) => DuoBarScaffold(
  style: DuoBarTheme.of(context).copyWith(tint: Colors.orange),
  body: body,
);

// --- layout helpers --------------------------------------------------------

void _helpers(BuildContext context, DuoState state) {
  final side = DuoLayout.barSide(
    MediaQuery.viewPaddingOf(context),
    state: state,
  );
  final width = DuoLayout.stripWidth(MediaQuery.viewPaddingOf(context));

  final (:top, :bottom) = DuoLayout.barInsets(
    size: MediaQuery.sizeOf(context),
    viewPadding: MediaQuery.viewPaddingOf(context),
    state: state,
  );

  final split = duoDivisionBand(state, const Size(400, 800));
  if (split != null) {
    debugPrint(
      '${split.horizontal ? 'top/bottom' : 'left/right'} at ${split.band}',
    );
  }

  final insets = duoOcclusionInsets(state, const Size(400, 800));

  final fitted = duoBarOverflow(
    groups: DuoVerticalBar.groupsOf(actions),
    available: 600,
  );

  debugPrint('$side $width $top $bottom $insets ${fitted.overflow.length}');
}

// --- testing ---------------------------------------------------------------

void _stage() {
  debugSetDuoState(
    const DuoState(
      isSupported: true,
      hingeStatus: DuoHingeStatus.partiallyOpen,
      verticalBarEdge: DuoVerticalBarEdge.trailing,
      hingeAngle: 2.2,
      regions: [
        DuoReservedRegion(
          kind: DuoRegionKind.division,
          left: 0,
          top: 380,
          width: 400,
          height: 40,
          marginLeft: 0,
          marginTop: 0,
          marginRight: 0,
          marginBottom: 0,
          isActive: true,
        ),
      ],
      cornerInsets: DuoInsets(left: 0, top: 0, right: 84, bottom: 34),
    ),
  );
  addTearDown(() => debugSetDuoState(null));
}
