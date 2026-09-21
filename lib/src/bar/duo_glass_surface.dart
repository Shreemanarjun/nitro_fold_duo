import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show Factory, defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../duo_bridge.dart';

/// A pane of Liquid Glass — the bar's material, without the buttons.
///
/// Put it behind chrome that content scrolls under, such as the leading-edge
/// title the system uses on Duo. On iOS this is the real `UIGlassEffect`,
/// hosted as a platform view; elsewhere it falls back to a blur of the same
/// shape.
///
/// It is decorative: touches pass through to whatever sits on top.
class DuoGlassSurface extends StatefulWidget {
  const DuoGlassSurface({
    super.key,
    this.borderRadius = 0,
    this.tint,
    this.child,
  });

  /// Corner radius in logical pixels. Zero is a square-edged band.
  final double borderRadius;

  /// Tints the material. Null leaves it plain.
  final Color? tint;

  /// Drawn on top of the material.
  final Widget? child;

  @override
  State<DuoGlassSurface> createState() => _DuoGlassSurfaceState();
}

class _DuoGlassSurfaceState extends State<DuoGlassSurface> {
  int? _viewId;

  /// The last shape handed to the native side, so a rebuild that changes
  /// nothing does not cross the bridge again.
  ({double radius, int tint, bool dark})? _pushed;

  void _attach(int id) {
    _viewId = id;
    _push();
  }

  void _push() {
    final id = _viewId;
    final duo = duoBridge;
    if (id == null || duo == null) return;

    final next = (
      radius: widget.borderRadius,
      tint: widget.tint?.toARGB32() ?? 0,
      dark: MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    );
    if (_pushed == next) return;
    _pushed = next;

    duo.updateGlassSurface(id, next.radius, next.tint, next.dark);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _push();
  }

  @override
  void didUpdateWidget(DuoGlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _push();
  }

  @override
  Widget build(BuildContext context) {
    final material = defaultTargetPlatform == TargetPlatform.iOS
        ? UiKitView(
            viewType: 'nitro_fold_duo/glass_surface',
            // Nothing in the material competes for touches, and the platform
            // view must not swallow them from the content above it.
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
            },
            onPlatformViewCreated: _attach,
          )
        : _fallback();

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: IgnorePointer(child: material)),
        ?widget.child,
      ],
    );
  }

  /// Not the system material, but the same read: a blur with the same shape.
  Widget _fallback() => ClipRRect(
    borderRadius: BorderRadius.circular(widget.borderRadius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: ColoredBox(color: widget.tint ?? const Color(0x1AFFFFFF)),
    ),
  );
}
