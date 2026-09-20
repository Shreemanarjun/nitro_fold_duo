/// One icon button in the vertical bar, named by its SF Symbol.
class DuoBarItem {
  const DuoBarItem({
    required this.symbol,
    this.title,
    this.onPressed,
    this.endsGroup = false,
  });

  /// SF Symbol name, e.g. `chevron.backward` or `square.and.arrow.up`.
  final String symbol;

  /// Label used when this item moves into the overflow menu, where an icon
  /// alone is not enough. Falls back to [symbol].
  final String? title;

  final void Function()? onPressed;

  /// Starts a new capsule after this item, keeping the groups a horizontal
  /// toolbar would show.
  final bool endsGroup;

  /// What the overflow menu shows for this item.
  String get menuTitle => title ?? symbol;
}
