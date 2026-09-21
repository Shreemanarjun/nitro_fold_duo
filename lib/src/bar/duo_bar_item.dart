/// How long an item keeps its place in the strip when the room runs out.
///
/// Mirrors `ToolbarItemVisibilityPriority`: items with a lower priority move
/// into the overflow menu before items with a higher one. Left alone,
/// everything is [automatic] and the bar overflows bottom to top.
extension type const DuoBarVisibilityPriority._(double rank) {
  /// Lower than [automatic]: first into the overflow menu.
  static const low = DuoBarVisibilityPriority._(-1);

  /// What an item has when nothing is said about it.
  static const automatic = DuoBarVisibilityPriority._(0);

  /// Higher than [automatic]: stays in the strip longer. For the action people
  /// reach for most, and for anything carrying status worth seeing at a glance.
  static const high = DuoBarVisibilityPriority._(1);

  factory DuoBarVisibilityPriority.lowerThan(DuoBarVisibilityPriority other) =>
      DuoBarVisibilityPriority._(other.rank - 1);

  factory DuoBarVisibilityPriority.higherThan(DuoBarVisibilityPriority other) =>
      DuoBarVisibilityPriority._(other.rank + 1);
}

/// One icon button in the vertical bar, named by its SF Symbol.
class DuoBarItem {
  const DuoBarItem({
    required this.symbol,
    required this.title,
    this.onPressed,
    this.endsGroup = false,
    this.menu = const <DuoBarItem>[],
    this.visibilityPriority = DuoBarVisibilityPriority.automatic,
  });

  /// SF Symbol name, e.g. `chevron.backward` or `square.and.arrow.up`.
  final String symbol;

  /// Accessibility label, and the wording the system shows for this item in a
  /// menu or an expanded form. Required: an icon announces nothing on its own,
  /// and a bar item without a title has nothing to fall back to.
  final String title;

  final void Function()? onPressed;

  /// Starts a new capsule after this item, keeping the groups a horizontal
  /// toolbar would show.
  final bool endsGroup;

  /// Entries behind this item in a real `UIMenu`. A button with a menu opens
  /// it rather than reporting a press, so [onPressed] is unused when this is
  /// not empty.
  final List<DuoBarItem> menu;

  /// How long this item keeps its place when the strip runs out of room.
  ///
  /// Capsules are kept whole, so a group is as important as its most important
  /// item. Set the same priority across a group to move it as a unit.
  final DuoBarVisibilityPriority visibilityPriority;

  DuoBarItem copyWith({List<DuoBarItem>? menu}) => DuoBarItem(
    symbol: symbol,
    title: title,
    onPressed: onPressed,
    endsGroup: endsGroup,
    menu: menu ?? this.menu,
    visibilityPriority: visibilityPriority,
  );
}
