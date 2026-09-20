import 'package:flutter/widgets.dart';

import '../nitro_fold_duo.native.dart';
import 'duo_bar_item.dart';
import 'duo_bar_metrics.dart';
import 'duo_bar_style.dart';
import 'duo_glass_capsule.dart';

/// Height one capsule takes for [count] buttons, including the gap below it.
double duoCapsuleExtent(int count, {DuoBarStyle style = const DuoBarStyle()}) =>
    style.capsuleExtent(count);

/// Splits toolbar [groups] into the capsules that fit in [available] points of
/// strip and the items that move into the system overflow menu.
///
/// Room for the overflow capsule itself is taken out of the budget first, so a
/// bar that overflows never overflows by exactly one item. Groups are kept
/// whole and in order: a group either fits or goes to the menu entire, which
/// keeps the pairing a horizontal toolbar would show.
({List<List<DuoBarItem>> visible, List<DuoBarItem> overflow}) duoBarOverflow({
  required List<List<DuoBarItem>> groups,
  required double available,
  DuoBarStyle style = const DuoBarStyle(),
}) {
  final total = groups.fold(
    0.0,
    (sum, g) => sum + style.capsuleExtent(g.length),
  );
  if (total <= available) {
    return (visible: groups, overflow: const <DuoBarItem>[]);
  }

  final budget = available - style.capsuleExtent(1);
  final visible = <List<DuoBarItem>>[];
  var used = 0.0;
  var index = 0;
  for (; index < groups.length; index++) {
    final extent = style.capsuleExtent(groups[index].length);
    if (used + extent > budget) break;
    used += extent;
    visible.add(groups[index]);
  }
  return (
    visible: visible,
    overflow: [for (final group in groups.skip(index)) ...group],
  );
}

/// The vertical bar used on iPhone Duo, laid out the way the system lays out
/// its own: from the top, below the status cluster, the primary navigation
/// control (back, close), then the toolbar items — each group in one glass
/// capsule — and at the bottom the tab bar as a capsule of icons.
///
/// Items that do not fit the strip move into a real `UIMenu` behind an
/// overflow capsule, as the system does.
class DuoVerticalBar extends StatelessWidget {
  const DuoVerticalBar({
    super.key,
    required this.state,
    this.leading,
    this.actions = const <DuoBarItem>[],
    this.tabs = const <DuoBarItem>[],
    this.selectedTab,
    this.tint,
    this.style,
  });

  /// Duo geometry, used to keep the controls clear of the camera.
  final DuoState state;

  /// Primary navigation control (back, close), placed first.
  final DuoBarItem? leading;

  /// The page's toolbar actions, in order. Consecutive actions share a capsule;
  /// [DuoBarItem.endsGroup] starts a new one.
  final List<DuoBarItem> actions;

  /// Tab bar shown as one capsule at the bottom of the strip.
  final List<DuoBarItem> tabs;

  final int? selectedTab;

  /// Shorthand for `style.tint`; the style wins when both are given.
  final Color? tint;

  /// Measurements and tint. Falls back to the nearest [DuoBarTheme], then to
  /// the system defaults.
  final DuoBarStyle? style;

  /// [actions] split into the groups that each get a capsule.
  static List<List<DuoBarItem>> groupsOf(List<DuoBarItem> actions) {
    final groups = <List<DuoBarItem>>[];
    var current = <DuoBarItem>[];
    for (final action in actions) {
      current.add(action);
      if (action.endsGroup) {
        groups.add(current);
        current = <DuoBarItem>[];
      }
    }
    if (current.isNotEmpty) groups.add(current);
    return groups;
  }

  Widget _capsule(
    DuoBarStyle style,
    List<DuoBarItem> items, {
    int? selectedIndex,
    Map<int, List<DuoBarItem>> menus = const {},
  }) => SizedBox(
    width: style.capsuleWidth,
    height: style.itemHeight * items.length,
    child: DuoGlassCapsule(
      symbols: [for (final item in items) item.symbol],
      titles: [for (final item in items) item.title ?? ''],
      selectedIndex: selectedIndex,
      menus: menus,
      tint: style.tint ?? tint,
      onPressed: (index, menuIndex) {
        if (menuIndex < 0) {
          items[index].onPressed?.call();
          return;
        }
        final entries = menus[index];
        if (entries != null && menuIndex < entries.length) {
          entries[menuIndex].onPressed?.call();
        }
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? DuoBarTheme.of(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final insets = DuoLayout.barInsets(
      size: MediaQuery.sizeOf(context),
      viewPadding: viewPadding,
      state: state,
      style: style,
    );

    return SizedBox(
      width: style.stripWidth ?? DuoLayout.stripWidth(viewPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // What the toolbar capsules get, once the fixed parts have taken
          // their room: the clearances, the leading control and the tab bar.
          final available =
              constraints.maxHeight -
              insets.top -
              insets.bottom -
              (leading == null ? 0 : style.capsuleExtent(1)) -
              (tabs.isEmpty ? 0 : style.capsuleExtent(tabs.length));

          final fitted = duoBarOverflow(
            groups: groupsOf(actions),
            available: available,
            style: style,
          );

          return Column(
            children: [
              SizedBox(height: insets.top),
              if (leading != null) ...[
                _capsule(style, [leading!]),
                SizedBox(height: style.groupSpacing),
              ],
              for (final group in fitted.visible) ...[
                _capsule(style, group),
                SizedBox(height: style.groupSpacing),
              ],
              if (fitted.overflow.isNotEmpty) ...[
                _capsule(
                  style,
                  [
                    DuoBarItem(
                      symbol: style.overflowSymbol,
                      title: style.overflowTitle,
                    ),
                  ],
                  menus: {0: fitted.overflow},
                ),
                SizedBox(height: style.groupSpacing),
              ],
              const Spacer(),
              if (tabs.isNotEmpty)
                _capsule(style, tabs, selectedIndex: selectedTab),
              SizedBox(height: insets.bottom),
            ],
          );
        },
      ),
    );
  }
}
