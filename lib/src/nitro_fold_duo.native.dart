import 'package:nitro/nitro.dart';

part 'nitro_fold_duo.g.dart';

/// Mirrors `UIHinge.Status` (UIKit, iOS 27.1). Raw values match the ObjC enum.
///
/// Status is system determined. There is no documented numeric angle range or
/// zero convention, so branch on this rather than on [DuoState.hingeAngle].
@HybridEnum()
enum DuoHingeStatus { unknown, closed, partiallyOpen, fullyOpen }

/// Mirrors `UIView.ReservedRegion.Kind` (UIKit, iOS 27.1).
@HybridEnum()
enum DuoRegionKind {
  /// Content can be obscured here, e.g. by a camera. Keep controls clear.
  occlusion,

  /// The region can separate content into independently usable areas, e.g. an
  /// active fold. Displace fixed controls or divide related panes.
  division,
}

/// A system-reserved region of the Flutter view.
///
/// [rect] is in Flutter logical pixels relative to the Flutter view's origin
/// and **already includes [margins]** — do not inset by the margins a second
/// time.
@HybridRecord()
class DuoReservedRegion {
  final DuoRegionKind kind;
  final double left;
  final double top;
  final double width;
  final double height;
  final double marginLeft;
  final double marginTop;
  final double marginRight;
  final double marginBottom;

  /// Whether the region currently applies. Inactive regions are reported so a
  /// layout can plan ahead; they should not reserve a blank gutter.
  final bool isActive;

  const DuoReservedRegion({
    required this.kind,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.marginLeft,
    required this.marginTop,
    required this.marginRight,
    required this.marginBottom,
    required this.isActive,
  });
}

/// A snapshot of the device's fold geometry and hinge.
@HybridRecord()
class DuoState {
  /// False when the OS/SDK predates the Duo APIs, or the plugin has not yet
  /// attached to a window. Everything else is then empty/unknown.
  final bool isSupported;

  final DuoHingeStatus hingeStatus;

  /// Hinge angle in radians, or null when no hinge is available in this
  /// context. The update rate and precision are system policy.
  final double? hingeAngle;

  /// Every reserved region known for the Flutter view, active or not.
  final List<DuoReservedRegion> regions;

  const DuoState({
    required this.isSupported,
    required this.hingeStatus,
    required this.hingeAngle,
    required this.regions,
  });
}
    
@NitroModule(
  ios: AppleNativeImpl.swift,
  android: AndroidNativeImpl.kotlin,
  macos: AppleNativeImpl.swift,
  windows: WindowsNativeImpl.cpp,
  linux: LinuxNativeImpl.cpp,
)
abstract class NitroFoldDuo extends HybridObject {
  static final NitroFoldDuo instance = _NitroFoldDuoImpl();

  double add(double a, double b);

  @nitroAsync
  Future<String> getGreeting(String name);

  /// The latest snapshot. Cheap — the native side keeps it cached and
  /// recomputes it on the platform main thread when the geometry changes.
  DuoState currentState();

  /// Emits whenever the reserved regions or the hinge change.
  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<DuoState> get stateChanges;
}
