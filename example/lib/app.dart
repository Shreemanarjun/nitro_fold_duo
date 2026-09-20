import 'package:flutter/material.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

import 'pages/home_page.dart';

class DuoDemoApp extends StatelessWidget {
  const DuoDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NitroFoldDuo Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
      // Publishes the fold through MediaQuery.displayFeatures, so Flutter's
      // own dialog and popup placement routes around the crease.
      builder: (context, child) => DuoDisplayFeatures(child: child!),
      home: const HomePage(),
    );
  }
}
