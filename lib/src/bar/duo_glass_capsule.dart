import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart'
    show Factory, defaultTargetPlatform, listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../duo_bridge.dart';
import '../nitro_fold_duo.native.dart';
import 'duo_bar_item.dart';
import 'duo_bar_metrics.dart';

/// A single Liquid Glass capsule holding a column of icon buttons.
///
/// On iOS this is the real `UIGlassEffect` material, hosted as a platform view
/// and configured over the Nitro FFI bridge. Everywhere else it falls back to a
/// blurred capsule of the same footprint.
class DuoGlassCapsule extends StatefulWidget {
  const DuoGlassCapsule({
    super.key,
    required this.items,
    this.selectedIndex,
    this.tint,
    this.symbolPointSize = kDuoBarSymbolPointSize,
  });

  /// The buttons, top to bottom. Each carries its own symbol, accessibility
  /// label, menu and callback, so there is no way for them to fall out of
  /// step with one another.
  final List<DuoBarItem> items;

  /// Index to draw a selection pill behind, for the tab capsule.
  final int? selectedIndex;

  final Color? tint;

  /// Point size of the SF Symbols drawn in the buttons.
  final double symbolPointSize;

  @override
  State<DuoGlassCapsule> createState() => _DuoGlassCapsuleState();
}

class _DuoGlassCapsuleState extends State<DuoGlassCapsule> {
  /// Presses arrive on one Nitro stream for every capsule at once, so they are
  /// demultiplexed here by platform view id rather than over a channel each.
  static final Map<int, void Function(int, int)> _handlers = {};
  static StreamSubscription<DuoBarPress>? _presses;

  int? _viewId;
  Map<int, List<String>> _pushedMenus = const {};

  /// What was last handed to the native side. The hinge angle ticks while the
  /// device folds, so the bar rebuilds many times a second with contents that
  /// have not changed; without this each rebuild would cross the bridge again.
  ({
    List<String> symbols,
    List<String> titles,
    int selected,
    int tint,
    double size,
    bool dark,
  })?
  _pushed;

  /// Runs the item a press belongs to — the button itself, or the entry chosen
  /// from its menu. Out-of-range indices are ignored rather than thrown: they
  /// can only mean the bar changed between the press and its delivery.
  void _dispatch(int index, int menuIndex) {
    if (index < 0 || index >= widget.items.length) return;
    final item = widget.items[index];
    if (menuIndex < 0) {
      item.onPressed?.call();
      return;
    }
    if (menuIndex < item.menu.length) item.menu[menuIndex].onPressed?.call();
  }

  void _attach(int id) {
    _viewId = id;
    _handlers[id] = _dispatch;
    // With no bridge the capsule still lays out, it just cannot report.
    _presses ??= duoBridge?.glassCapsulePresses.listen(
      (press) => _handlers[press.viewId]?.call(press.index, press.menuIndex),
    );
    _push();
  }

  void _push() {
    final id = _viewId;
    final duo = duoBridge;
    if (id == null || duo == null) return;
    _pushContents(duo, id);
    _pushMenus(duo, id);
  }

  /// The buttons themselves. Skipped when nothing about them changed.
  void _pushContents(NitroFoldDuo duo, int id) {
    final next = (
      symbols: [for (final item in widget.items) item.symbol],
      titles: [for (final item in widget.items) item.title ?? ''],
      selected: widget.selectedIndex ?? -1,
      tint: widget.tint?.toARGB32() ?? 0,
      size: widget.symbolPointSize,
      dark: MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    );
    final previous = _pushed;
    if (previous != null &&
        previous.selected == next.selected &&
        previous.tint == next.tint &&
        previous.size == next.size &&
        previous.dark == next.dark &&
        listEquals(previous.symbols, next.symbols) &&
        listEquals(previous.titles, next.titles)) {
      return;
    }
    // Rebuilding the buttons on the native side drops their menus, so a
    // contents push invalidates every menu behind it.
    _pushedMenus = const {};
    _pushed = next;

    duo.updateGlassCapsule(
      id,
      next.symbols,
      next.titles,
      next.selected,
      next.tint,
      next.size,
      next.dark,
    );
  }

  /// The overflow menus, diffed per button: one that gained, changed or lost
  /// its entries is pushed, and one that is unchanged is left alone.
  void _pushMenus(NitroFoldDuo duo, int id) {
    final next = <int, List<String>>{};
    for (final (index, item) in widget.items.indexed) {
      if (item.menu.isEmpty) continue;
      next[index] = [
        for (final entry in item.menu) '${entry.menuTitle}\u0000${entry.symbol}',
      ];
    }

    for (final MapEntry(key: index, value: entries) in next.entries) {
      if (listEquals(_pushedMenus[index], entries)) continue;
      final menu = widget.items[index].menu;
      duo.setGlassCapsuleMenu(
        id,
        index,
        [for (final entry in menu) entry.menuTitle],
        [for (final entry in menu) entry.symbol],
      );
    }
    for (final index in _pushedMenus.keys.toSet().difference(next.keys.toSet())) {
      duo.setGlassCapsuleMenu(id, index, const [], const []);
    }
    _pushedMenus = next;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _push();
  }

  @override
  void didUpdateWidget(DuoGlassCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    _push();
  }

  @override
  void dispose() {
    final id = _viewId;
    if (id != null) _handlers.remove(id);
    if (_handlers.isEmpty) {
      _presses?.cancel();
      _presses = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return _fallback();
    // Contents are pushed over the Nitro bridge once the view exists, so no
    // creation params and no per-view channel.
    return UiKitView(
      viewType: 'nitro_fold_duo/glass_capsule',
      // The capsule is entirely native and nothing in Flutter competes for
      // these touches, so let it win the arena at once. Without this the
      // platform view only sees a touch after Flutter's recognisers give up,
      // and short synthesised taps — UI tests, assistive input — are lost.
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
      onPlatformViewCreated: _attach,
    );
  }

  /// Not the system material, but the same shape and footprint, so a Duo strip
  /// laid out on another platform still reads correctly.
  Widget _fallback() => ClipRRect(
    borderRadius: BorderRadius.circular(kDuoBarCapsuleWidth / 2),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: ColoredBox(
        color: const Color(0x33FFFFFF),
        child: Column(
          children: [
            for (final (index, _) in widget.items.indexed)
              Expanded(
                child: GestureDetector(
                  onTap: () => _dispatch(index, -1),
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
