import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/widgets.dart';

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
    required this.symbols,
    this.selectedIndex,
    this.menus = const <int, List<DuoBarItem>>{},
    this.tint,
    this.onPressed,
  });

  /// SF Symbol names, top to bottom.
  final List<String> symbols;

  /// Index to draw a selection pill behind, for the tab capsule.
  final int? selectedIndex;

  /// Overflow menu entries for the button at each index. A button with a menu
  /// opens it instead of reporting a plain press.
  final Map<int, List<DuoBarItem>> menus;

  final Color? tint;

  /// `menuIndex` is negative for a plain press, otherwise the chosen entry.
  final void Function(int index, int menuIndex)? onPressed;

  @override
  State<DuoGlassCapsule> createState() => _DuoGlassCapsuleState();
}

class _DuoGlassCapsuleState extends State<DuoGlassCapsule> {
  /// Presses arrive on one Nitro stream for every capsule at once, so they are
  /// demultiplexed here by platform view id rather than over a channel each.
  static final Map<int, void Function(int, int)> _handlers = {};
  static StreamSubscription<DuoBarPress>? _presses;

  int? _viewId;
  Set<int> _pushedMenus = const {};

  void _attach(int id) {
    _viewId = id;
    _handlers[id] = (index, menuIndex) =>
        widget.onPressed?.call(index, menuIndex);
    _presses ??= NitroFoldDuo.instance.glassCapsulePresses.listen(
      (press) => _handlers[press.viewId]?.call(press.index, press.menuIndex),
    );
    _push();
  }

  void _push() {
    final id = _viewId;
    if (id == null) return;
    final duo = NitroFoldDuo.instance;
    duo.updateGlassCapsule(
      id,
      widget.symbols,
      widget.selectedIndex ?? -1,
      widget.tint?.toARGB32() ?? 0,
      MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    );

    // Rebuilding the buttons drops their menus, so push every menu after the
    // contents, and clear any button that had one and no longer does.
    for (final index in widget.menus.keys) {
      final entries = widget.menus[index]!;
      duo.setGlassCapsuleMenu(
        id,
        index,
        [for (final entry in entries) entry.menuTitle],
        [for (final entry in entries) entry.symbol],
      );
    }
    for (final index in _pushedMenus.difference(widget.menus.keys.toSet())) {
      duo.setGlassCapsuleMenu(id, index, const [], const []);
    }
    _pushedMenus = widget.menus.keys.toSet();
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
            for (var i = 0; i < widget.symbols.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => widget.onPressed?.call(i, -1),
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
