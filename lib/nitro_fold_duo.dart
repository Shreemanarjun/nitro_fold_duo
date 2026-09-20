/// iPhone Duo support: fold and camera geometry, hinge state, and the system's
/// vertical control bar.
///
/// The device is exposed as signals — read [duoState] inside a `SignalBuilder`
/// and a widget rebuilds when the device folds, rotates or moves display.
/// `signals_flutter` is re-exported, so that is the only import you need.
library;

export 'package:signals_flutter/signals_flutter.dart';

export 'src/bar/duo_bar_item.dart';
export 'src/bar/duo_bar_metrics.dart';
export 'src/bar/duo_bar_scaffold.dart';
export 'src/bar/duo_bar_style.dart';
export 'src/bar/duo_glass_capsule.dart';
export 'src/bar/duo_vertical_bar.dart';
export 'src/duo_bridge.dart';
export 'src/geometry/duo_geometry.dart';
export 'src/geometry/duo_signals.dart';
export 'src/nitro_fold_duo.native.dart';
export 'src/widgets/duo_builder.dart';
export 'src/widgets/duo_occlusion_safe_area.dart';
export 'src/widgets/duo_split.dart';
