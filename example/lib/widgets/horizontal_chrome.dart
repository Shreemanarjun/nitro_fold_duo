import 'package:flutter/material.dart';

/// The ordinary app bar and tab bar, drawn wherever the system keeps bars
/// horizontal: the Duo inner display in portrait, and every other iPhone.
class HorizontalChrome extends StatelessWidget {
  const HorizontalChrome({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
    this.actions = const <Widget>[],
    this.selectedTab,
    this.onTabSelected,
  });

  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final int? selectedTab;
  final ValueChanged<int>? onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Row(
            children: [
              if (onBack != null)
                BackButton(key: const Key('horizontalBack'), onPressed: onBack)
              else
                const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              ...actions,
            ],
          ),
        ),
        Expanded(child: body),
        if (selectedTab != null)
          NavigationBar(
            selectedIndex: selectedTab!,
            onDestinationSelected: onTabSelected,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.info_outline), label: 'State'),
              NavigationDestination(icon: Icon(Icons.splitscreen), label: 'Split'),
            ],
          ),
      ],
    );
  }
}
