/// One icon button in the vertical bar, named by its SF Symbol.
class DuoBarItem {
  const DuoBarItem({
    required this.symbol,
    this.title,
    this.onPressed,
    this.endsGroup = false,
    this.menu = const <DuoBarItem>[],
  });

  /// SF Symbol name, e.g. `chevron.backward` or `square.and.arrow.up`.
  final String symbol;

  /// Accessibility label, and the wording used when this item appears in a
  /// menu. An icon announces nothing on its own, so give every item one.
  final String? title;

  final void Function()? onPressed;

  /// Starts a new capsule after this item, keeping the groups a horizontal
  /// toolbar would show.
  final bool endsGroup;

  /// Entries behind this item in a real `UIMenu`. A button with a menu opens
  /// it rather than reporting a press, so [onPressed] is unused when this is
  /// not empty.
  final List<DuoBarItem> menu;

  /// What a menu shows for this item.
  String get menuTitle => title ?? symbol;

  DuoBarItem copyWith({List<DuoBarItem>? menu}) => DuoBarItem(
    symbol: symbol,
    title: title,
    onPressed: onPressed,
    endsGroup: endsGroup,
    menu: menu ?? this.menu,
  );
}
