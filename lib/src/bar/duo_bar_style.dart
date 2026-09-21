import 'package:flutter/widgets.dart';

import 'duo_bar_metrics.dart';

/// What gives way first when the strip runs out of room.
///
/// Mirrors `UIVerticalBarCompressionBehavior` — SwiftUI spells the same choice
/// `.toolbarVerticalCompressionBehavior(.prefersToolbarItems)`.
enum DuoBarCompression {
  /// What the system does: keep the tab bar whole and move the toolbar items
  /// that no longer fit into the overflow menu.
  automatic,

  /// Keep the toolbar items in the strip. The tab bar gives up its room
  /// instead, collapsing to a single button whose menu lists the tabs.
  prefersBarItems,

  /// Keep the tab bar whole, as [automatic] does. Spelled out for a call site
  /// that wants to say so rather than rely on the default.
  prefersTabBar;

  /// Whether the tab bar should collapse before the toolbar overflows.
  bool get compressesTabBar => switch (this) {
    DuoBarCompression.prefersBarItems => true,
    DuoBarCompression.automatic || DuoBarCompression.prefersTabBar => false,
  };
}

/// The measurements and tint the vertical bar is drawn with.
///
/// The defaults match what the system uses. Override one when your own chrome
/// needs to line up with something else — a taller touch target, a brand tint,
/// a strip width the system has not reported yet.
@immutable
class DuoBarStyle {
  const DuoBarStyle({
    this.capsuleWidth = kDuoBarCapsuleWidth,
    this.itemHeight = kDuoBarItemHeight,
    this.groupSpacing = kDuoBarGroupSpacing,
    this.edgeMargin = kDuoBarEdgeMargin,
    this.titleBandHeight = kDuoTitleBandHeight,
    this.overflowSymbol = kDuoOverflowSymbol,
    this.overflowTitle = 'More',
    this.compression = DuoBarCompression.automatic,
    this.symbolPointSize = kDuoBarSymbolPointSize,
    this.titlePadding = const EdgeInsetsDirectional.only(start: 20),
    this.titleBackdropRadius = 0,
    this.stripWidth,
    this.tint,
  });

  /// Width of a capsule, centred in the strip.
  final double capsuleWidth;

  /// Height of one icon button inside a capsule.
  final double itemHeight;

  /// Space between capsules.
  final double groupSpacing;

  /// Space kept between the controls and a free edge of the window.
  final double edgeMargin;

  /// Height of the band holding the leading-edge title.
  final double titleBandHeight;

  /// SF Symbol for the overflow capsule.
  final String overflowSymbol;

  /// Accessibility label for the overflow capsule.
  final String overflowTitle;

  /// What gives way when the strip runs out of room.
  final DuoBarCompression compression;

  /// Point size of the SF Symbols in a capsule. Raise it with
  /// [capsuleWidth] so the icons keep their proportion.
  final double symbolPointSize;

  /// Insets the leading-edge title inside its band.
  final EdgeInsetsGeometry titlePadding;

  /// Corner radius of the material behind the title. Square by default, as the
  /// system's own band is.
  final double titleBackdropRadius;

  /// Overrides the strip width the system reserves. Leave null to follow the
  /// window's own inset, which is what the system bar uses.
  final double? stripWidth;

  /// Tint for the capsule buttons. Null uses the system label colour.
  final Color? tint;

  /// Height one capsule takes for [count] buttons, including the gap below it.
  double capsuleExtent(int count) => itemHeight * count + groupSpacing;

  DuoBarStyle copyWith({
    double? capsuleWidth,
    double? itemHeight,
    double? groupSpacing,
    double? edgeMargin,
    double? titleBandHeight,
    String? overflowSymbol,
    String? overflowTitle,
    DuoBarCompression? compression,
    double? symbolPointSize,
    EdgeInsetsGeometry? titlePadding,
    double? titleBackdropRadius,
    double? stripWidth,
    Color? tint,
  }) => DuoBarStyle(
    capsuleWidth: capsuleWidth ?? this.capsuleWidth,
    itemHeight: itemHeight ?? this.itemHeight,
    groupSpacing: groupSpacing ?? this.groupSpacing,
    edgeMargin: edgeMargin ?? this.edgeMargin,
    titleBandHeight: titleBandHeight ?? this.titleBandHeight,
    overflowSymbol: overflowSymbol ?? this.overflowSymbol,
    overflowTitle: overflowTitle ?? this.overflowTitle,
    compression: compression ?? this.compression,
    symbolPointSize: symbolPointSize ?? this.symbolPointSize,
    titlePadding: titlePadding ?? this.titlePadding,
    titleBackdropRadius: titleBackdropRadius ?? this.titleBackdropRadius,
    stripWidth: stripWidth ?? this.stripWidth,
    tint: tint ?? this.tint,
  );

  @override
  bool operator ==(Object other) =>
      other is DuoBarStyle &&
      other.capsuleWidth == capsuleWidth &&
      other.itemHeight == itemHeight &&
      other.groupSpacing == groupSpacing &&
      other.edgeMargin == edgeMargin &&
      other.titleBandHeight == titleBandHeight &&
      other.overflowSymbol == overflowSymbol &&
      other.overflowTitle == overflowTitle &&
      other.compression == compression &&
      other.symbolPointSize == symbolPointSize &&
      other.titlePadding == titlePadding &&
      other.titleBackdropRadius == titleBackdropRadius &&
      other.stripWidth == stripWidth &&
      other.tint == tint;

  @override
  int get hashCode => Object.hash(
    capsuleWidth,
    itemHeight,
    groupSpacing,
    edgeMargin,
    titleBandHeight,
    overflowSymbol,
    overflowTitle,
    compression,
    symbolPointSize,
    titlePadding,
    titleBackdropRadius,
    stripWidth,
    tint,
  );
}

/// Applies a [DuoBarStyle] to every bar below it, so an app sets its bar
/// measurements once rather than at each call site.
class DuoBarTheme extends InheritedWidget {
  const DuoBarTheme({super.key, required this.style, required super.child});

  final DuoBarStyle style;

  /// The nearest ancestor style, or the system defaults when there is none.
  static DuoBarStyle of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DuoBarTheme>()?.style ??
      const DuoBarStyle();

  @override
  bool updateShouldNotify(DuoBarTheme oldWidget) => oldWidget.style != style;
}
