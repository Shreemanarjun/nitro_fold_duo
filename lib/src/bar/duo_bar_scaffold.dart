import 'package:flutter/widgets.dart';

import 'package:signals_flutter/signals_flutter.dart';

import '../geometry/duo_signals.dart';
import 'duo_bar_item.dart';
import 'duo_bar_metrics.dart';
import 'duo_bar_style.dart';
import 'duo_glass_surface.dart';
import 'duo_vertical_bar.dart';

/// Keeps [body] clear of the Duo vertical strip and draws the bar in it.
///
/// Where the system keeps bars horizontal — the inner display in portrait, and
/// every other iPhone — the strip does not exist and [horizontalChrome] draws
/// your ordinary app bar and tab bar around [body] instead.
class DuoBarScaffold extends StatelessWidget {
  const DuoBarScaffold({
    super.key,
    required this.body,
    this.horizontalChrome,
    this.title,
    this.leading,
    this.actions = const <DuoBarItem>[],
    this.tabs = const <DuoBarItem>[],
    this.selectedTab,
    this.tint,
    this.style,
    this.titleBackdrop = true,
  });

  final Widget body;

  /// Draws your normal chrome around [body] when there is no vertical strip.
  final Widget Function(BuildContext context, Widget body)? horizontalChrome;

  /// Shown at the leading edge above [body] while the strip exists, because the
  /// navigation controls live in the strip rather than beside the title.
  final Widget? title;

  final DuoBarItem? leading;
  final List<DuoBarItem> actions;
  final List<DuoBarItem> tabs;
  final int? selectedTab;
  final Color? tint;

  /// Measurements and tint. Falls back to the nearest [DuoBarTheme], then to
  /// the system defaults.
  final DuoBarStyle? style;

  /// Draws the system's material behind [title], so content scrolling under
  /// the band stays legible. Turn it off for a body that already provides its
  /// own background there.
  final bool titleBackdrop;

  Widget _titleBand(DuoBarStyle style) {
    final label = Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(padding: style.titlePadding, child: title),
    );
    return titleBackdrop
        ? DuoGlassSurface(
            borderRadius: style.titleBackdropRadius,
            tint: style.tint,
            child: label,
          )
        : label;
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final state = duoState.value;
        final barStyle = style ?? DuoBarTheme.of(context);
        final viewPadding = MediaQuery.viewPaddingOf(context);
        final side = DuoLayout.barSide(viewPadding, state: state);
        if (side == null) {
          return horizontalChrome?.call(context, body) ?? body;
        }

        final strip = barStyle.stripWidth ?? DuoLayout.stripWidth(viewPadding);
        final content = Padding(
          padding: switch (side) {
            DuoBarSide.left => EdgeInsets.only(left: strip),
            DuoBarSide.right => EdgeInsets.only(right: strip),
          },
          child: title == null
              ? body
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The system sets the title at the leading edge, clear of
                    // the bezel, because the controls live in the strip.
                    SizedBox(
                      height: barStyle.titleBandHeight,
                      child: _titleBand(barStyle),
                    ),
                    Expanded(child: body),
                  ],
                ),
        );

        return Stack(
          children: [
            Positioned.fill(child: content),
            Positioned(
              top: 0,
              bottom: 0,
              left: switch (side) {
                DuoBarSide.left => 0,
                DuoBarSide.right => null,
              },
              right: switch (side) {
                DuoBarSide.left => null,
                DuoBarSide.right => 0,
              },
              child: DuoVerticalBar(
                state: state,
                leading: leading,
                actions: actions,
                tabs: tabs,
                selectedTab: selectedTab,
                tint: tint,
                style: barStyle,
              ),
            ),
          ],
        );
      },
    );
  }
}
