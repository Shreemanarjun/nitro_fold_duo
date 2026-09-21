import 'package:flutter/material.dart';

import '../pages/home_page.dart';

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
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              ...actions,
            ],
          ),
        ),
        // The tab bar below takes the home-indicator inset, so the body must
        // not be offered it a second time.
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: selectedTab != null,
            child: body,
          ),
        ),
        if (selectedTab != null)
          NavigationBar(
            selectedIndex: selectedTab!,
            onDestinationSelected: onTabSelected,
            destinations: [
              for (final tab in DemoTab.values)
                NavigationDestination(icon: Icon(tab.icon), label: tab.title),
            ],
          ),
      ],
    );
  }
}
