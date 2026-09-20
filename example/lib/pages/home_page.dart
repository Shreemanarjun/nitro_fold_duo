import 'package:flutter/material.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

import '../widgets/duo_state_readout.dart';
import '../widgets/duo_status_line.dart';
import '../widgets/horizontal_chrome.dart';
import 'detail_page.dart';
import 'reader_page.dart';

/// Two tabs: a reader that splits across the fold, and the raw state the
/// bridge reports.
enum DemoTab {
  reader(symbol: 'text.justify', title: 'Read', icon: Icons.article_outlined),
  state(symbol: 'info.circle', title: 'State', icon: Icons.info_outline);

  const DemoTab({required this.symbol, required this.title, required this.icon});

  final String symbol;
  final String title;
  final IconData icon;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DemoTab _tab = DemoTab.reader;
  int _article = 0;
  String _action = '—';

  void _record(String action) => setState(() => _action = action);

  void _openDetail() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const DetailPage()));

  /// Deliberately more actions than the strip can hold, so the tail lands in
  /// the system overflow menu.
  List<DuoBarItem> get _actions => [
    DuoBarItem(
      symbol: 'rectangle.split.2x1',
      title: 'Fold-aware dialog',
      onPressed: () => showFoldAwareDialog(context),
    ),
    DuoBarItem(
      symbol: 'square.and.arrow.up',
      title: 'Share',
      endsGroup: true,
      onPressed: () => _record('share'),
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
    final body = switch (_tab) {
      DemoTab.reader => ReaderPage(
        selected: _article,
        onSelected: (index) => setState(() => _article = index),
      ),
      DemoTab.state => DuoStateReadout(
        lastAction: _action,
        onReset: () => _record('reset'),
      ),
    };

    // The status line sits under whichever tab is up, so the device's state is
    // always on screen.
    final content = Column(
      children: [Expanded(child: body), const DuoStatusLine()],
    );

    return Scaffold(
      body: DuoBarScaffold(
        title: const Text(
          'Fold Duo',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: _actions,
        tabs: [
          for (final tab in DemoTab.values)
            DuoBarItem(
              symbol: tab.symbol,
              title: tab.title,
              onPressed: () => setState(() => _tab = tab),
            ),
        ],
        selectedTab: _tab.index,
        horizontalChrome: (context, body) => HorizontalChrome(
          title: 'Fold Duo',
          body: body,
          selectedTab: _tab.index,
          onTabSelected: (index) =>
              setState(() => _tab = DemoTab.values[index]),
          actions: [
            IconButton(
              key: const Key('horizontalDialog'),
              onPressed: () => showFoldAwareDialog(context),
              icon: const Icon(Icons.splitscreen),
            ),
            IconButton(
              key: const Key('horizontalShare'),
              onPressed: () => _record('share'),
              icon: const Icon(Icons.ios_share),
            ),
            IconButton(
              key: const Key('horizontalDetail'),
              onPressed: _openDetail,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        body: content,
      ),
    );
  }
}
