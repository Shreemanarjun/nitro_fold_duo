import 'package:flutter/material.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

import '../widgets/horizontal_chrome.dart';

/// Pushed page — exercises the back control in the vertical bar.
class DetailPage extends StatelessWidget {
  const DetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    void pop() => Navigator.of(context).pop();

    return Scaffold(
      body: DuoBarScaffold(
        title: const Text(
          'Detail',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        leading: DuoBarItem(
          symbol: 'chevron.backward',
          title: 'Back',
          onPressed: pop,
        ),
        horizontalChrome: (context, body) =>
            HorizontalChrome(title: 'Detail', onBack: pop, body: body),
        body: const Center(
          key: Key('detailBody'),
          child: Text('Pushed page — use the back control'),
        ),
      ),
    );
  }
}
