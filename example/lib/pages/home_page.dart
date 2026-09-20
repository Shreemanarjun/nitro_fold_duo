import 'package:flutter/material.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

import '../widgets/demo_pane.dart';
import '../widgets/duo_state_readout.dart';
import '../widgets/horizontal_chrome.dart';
import 'detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  String _action = '—';

  void _record(String action) => setState(() => _action = action);

  void _openDetail() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const DetailPage()));

  /// Deliberately more actions than the strip can hold, so the tail lands in
  /// the system overflow menu.
  List<DuoBarItem> get _actions => [
    DuoBarItem(
      symbol: 'square.and.arrow.up',
      title: 'Share',
      onPressed: () => _record('share'),
    ),
    DuoBarItem(
      symbol: 'gearshape',
      title: 'Settings',
      endsGroup: true,
      onPressed: () => _record('settings'),
    ),
    DuoBarItem(
      symbol: 'chevron.right.circle',
      title: 'Open detail',
      endsGroup: true,
      onPressed: _openDetail,
    ),
    DuoBarItem(
      symbol: 'bookmark',
      title: 'Bookmark',
      onPressed: () => _record('bookmark'),
    ),
    DuoBarItem(symbol: 'tag', title: 'Tag', onPressed: () => _record('tag')),
    DuoBarItem(
      symbol: 'flag',
      title: 'Flag',
      endsGroup: true,
      onPressed: () => _record('flag'),
    ),
    DuoBarItem(
      symbol: 'textformat',
      title: 'Format',
      onPressed: () => _record('format'),
    ),
    DuoBarItem(
      symbol: 'paintbrush',
      title: 'Theme',
      endsGroup: true,
      onPressed: () => _record('theme'),
    ),
    DuoBarItem(
      symbol: 'wand.and.stars',
      title: 'Enhance',
      onPressed: () => _record('enhance'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final body = _tab == 0
        ? DuoStateReadout(lastAction: _action)
        : const DuoSplit(
            primary: DemoPane(label: 'PRIMARY', color: Colors.deepPurple),
            secondary: DemoPane(label: 'SECONDARY', color: Colors.teal),
          );

    return Scaffold(
      body: DuoBarScaffold(
        title: const Text(
          'Fold Duo',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: _actions,
        tabs: [
          DuoBarItem(
            symbol: 'info.circle',
            title: 'State',
            onPressed: () => setState(() => _tab = 0),
          ),
          DuoBarItem(
            symbol: 'rectangle.split.2x1',
            title: 'Split',
            onPressed: () => setState(() => _tab = 1),
          ),
        ],
        selectedTab: _tab,
        horizontalChrome: (context, body) => HorizontalChrome(
          title: 'Fold Duo',
          body: body,
          selectedTab: _tab,
          onTabSelected: (index) => setState(() => _tab = index),
          actions: [
            IconButton(
              key: const Key('horizontalShare'),
              onPressed: () => _record('share'),
              icon: const Icon(Icons.ios_share),
            ),
            IconButton(
              onPressed: () => _record('settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
            IconButton(
              key: const Key('horizontalDetail'),
              onPressed: _openDetail,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        body: body,
      ),
    );
  }
}
