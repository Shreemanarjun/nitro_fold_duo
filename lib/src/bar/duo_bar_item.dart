/// One icon button in the vertical bar, named by its SF Symbol.
class DuoBarItem {
  const DuoBarItem({
    required this.symbol,
    required this.title,
    this.onPressed,
    this.endsGroup = false,
    this.menu = const <DuoBarItem>[],
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

  DuoBarItem copyWith({List<DuoBarItem>? menu}) => DuoBarItem(
    symbol: symbol,
    title: title,
    onPressed: onPressed,
    endsGroup: endsGroup,
    menu: menu ?? this.menu,
  );
}
