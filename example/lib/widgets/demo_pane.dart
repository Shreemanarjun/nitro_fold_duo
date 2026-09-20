import 'package:flutter/material.dart';

/// A flat coloured pane, so a split is obvious in a screenshot.
class DemoPane extends StatelessWidget {
  const DemoPane({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: color.withValues(alpha: 0.15),
    child: Center(
      child: Text(label, key: Key('pane_$label'), style: TextStyle(color: color)),
    ),
  );
}
