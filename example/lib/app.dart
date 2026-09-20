import 'package:flutter/material.dart';

import 'pages/home_page.dart';

class DuoDemoApp extends StatelessWidget {
  const DuoDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NitroFoldDuo Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
      home: const HomePage(),
    );
  }
}
