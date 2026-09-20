import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../geometry/duo_geometry.dart';
import '../geometry/duo_signals.dart';
import '../nitro_fold_duo.native.dart';

/// Translates [DuoState] into the display features Flutter already understands.
///
/// [DisplayFeatureState.postureHalfOpened] only for a division that is really
/// dividing: a flat fold is reported inactive by the device, and a crease you
/// cannot see is not something a layout should route around.
List<DisplayFeature> duoDisplayFeatures(DuoState state) => [
  for (final region in state.regions)
    if (region.isActive)
      DisplayFeature(
        bounds: region.rect,
        type: switch (region.kind) {
          // A Duo's crease is a flexible screen, not a gap between panels.
          DuoRegionKind.division => DisplayFeatureType.fold,
          DuoRegionKind.occlusion => DisplayFeatureType.cutout,
        },
        state: switch (region.kind) {
          DuoRegionKind.division => switch (state.hingeStatus) {
            DuoHingeStatus.partiallyOpen =>
              DisplayFeatureState.postureHalfOpened,
            DuoHingeStatus.fullyOpen => DisplayFeatureState.postureFlat,
            DuoHingeStatus.closed ||
            DuoHingeStatus.unknown => DisplayFeatureState.unknown,
          },
          // Flutter documents cutouts as carrying no posture.
          DuoRegionKind.occlusion => DisplayFeatureState.unknown,
        },
      ),
];

/// Publishes the Duo's fold and cameras through `MediaQuery.displayFeatures`.
///
/// Flutter has modelled a fold since `DisplayFeature` landed, but `dart:ui`
/// only fills it in on Android: on an iPhone Duo `MediaQuery.displayFeaturesOf`
/// comes back empty however you hold the phone. Everything built on it —
/// `DisplayFeatureSubScreen`, and so every dialog, popup menu and route that
/// already keeps clear of a hinge on a Fold — therefore does nothing here.
///
/// Wrapping your app in this fills that gap from the reserved regions iOS does
/// report, so the widgets you already have behave the same on both:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => DuoDisplayFeatures(child: child!),
///   home: const HomePage(),
/// )
/// ```
///
/// It adds to whatever the platform reported rather than replacing it, so an
/// Android foldable keeps its own features untouched.
class DuoDisplayFeatures extends StatelessWidget {
  const DuoDisplayFeatures({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final features = duoDisplayFeatures(duoState.value);
        if (features.isEmpty) return child;

        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            displayFeatures: [...media.displayFeatures, ...features],
          ),
          child: child,
        );
      },
    );
  }
}
