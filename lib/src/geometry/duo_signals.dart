import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:signals_flutter/signals_flutter.dart';

import '../duo_bridge.dart';
import '../nitro_fold_duo.native.dart';
import 'duo_geometry.dart';

Signal<DuoState>? _state;
StreamSubscription<DuoState>? _link;

/// The live fold, camera and hinge state of the device.
///
/// Read it inside a [SignalBuilder] — or with `duoState.watch(context)` — and
/// the widget rebuilds whenever the device changes:
///
/// ```dart
/// SignalBuilder(builder: (context) => Text(duoState.value.hingeStatus.name))
/// ```
///
/// It always has a value. Where the native bridge is unavailable — under
/// `flutter test`, or on a platform the plugin does not build for — that value
/// is [duoStateUnavailable] rather than an error.
///
/// The native subscription starts on first read and is shared by every
/// listener, so reading this from many widgets costs one bridge stream.
ReadonlySignal<DuoState> get duoState {
  final existing = _state;
  if (existing != null) return existing;

  final created = signal<DuoState>(
    _readInitial(),
    options: SignalOptions<DuoState>(name: 'duoState'),
  );
  _state = created;
  _bind();
  return created;
}

/// Points the signal at whatever bridge is current. One subscription serves
/// every listener, and it lives as long as the app does.
void _bind() {
  _link?.cancel();
  _link = duoBridge?.stateChanges.listen((next) => _state!.value = next);
}

DuoState _readInitial() => duoBridge?.currentState() ?? duoStateUnavailable;

/// The fold that is currently dividing the display, or null when the device is
/// flat, closed, or has no fold at all.
///
/// Derived, so a layout that only cares about the fold is not rebuilt every
/// time the hinge angle ticks.
final ReadonlySignal<DuoReservedRegion?> duoActiveDivision = computed(
  () => duoState.value.activeDivision,
  options: ComputedOptions(name: 'duoActiveDivision'),
);

/// Regions that can currently obscure content, such as a camera.
final ReadonlySignal<List<DuoReservedRegion>> duoActiveOcclusions =
    computed(
      () => duoState.value.activeOcclusions.toList(),
      options: ComputedOptions(name: 'duoActiveOcclusions'),
    );

/// Whether the device is closed, partly folded, or flat.
///
/// Branch on this rather than on the angle: no numeric range or zero
/// convention is documented, and the update rate is system policy.
final ReadonlySignal<DuoHingeStatus> duoHingeStatus = computed(
  () => duoState.value.hingeStatus,
  options: ComputedOptions(name: 'duoHingeStatus'),
);

/// The edge the system reserves for the vertical bar, whether or not one is
/// currently visible.
final ReadonlySignal<DuoVerticalBarEdge> duoVerticalBarEdge = computed(
  () => duoState.value.verticalBarEdge,
  options: ComputedOptions(name: 'duoVerticalBarEdge'),
);

/// Publishes [state] as though the device had reported it.
///
/// For tests and widget previews: it lets a fold, a camera or a bar edge be
/// staged without a device. Pass null to drop back to what the device reports.
@visibleForTesting
void debugSetDuoState(DuoState? state) {
  // Read the getter first so the signal exists, then write through it. The
  // signal is never replaced: the derived signals track this instance, and
  // swapping it would leave them watching something nothing writes to.
  duoState;
  if (state != null) {
    _state!.value = state;
    return;
  }
  // Going back to the device also means re-reading which bridge that is: a
  // test may have swapped it since the signal was created.
  _bind();
  _state!.value = _readInitial();
}
