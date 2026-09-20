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

/// Mirrors `UIVerticalBarEdge` (UIKit, iOS 27.1): the edge where the system
/// places the vertical bar — the status cluster, back button, toolbar and tab
/// bar that move off the top on the cover display and in inner landscape.
///
/// This reflects the system's preferred edge whether or not a bar is currently
/// visible, so it is not a visibility flag. [unspecified] means the system
/// never places one here — including the inner display in portrait, where the
/// bars stay horizontal.
@HybridEnum()
enum DuoVerticalBarEdge { unspecified, leading, trailing }

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

  /// Which edge the system reserves for the vertical bar.
  final DuoVerticalBarEdge verticalBarEdge;

  /// Hinge angle in radians, or null when no hinge is available in this
  /// context. The update rate and precision are system policy.
  final double? hingeAngle;

  /// Every reserved region known for the Flutter view, active or not.
  final List<DuoReservedRegion> regions;

  const DuoState({
    required this.isSupported,
    required this.hingeStatus,
    required this.verticalBarEdge,
    required this.hingeAngle,
    required this.regions,
  });
}
    
/// A button press in a native Liquid Glass capsule, tagged with the platform
/// view that owns it.
@HybridRecord()
class DuoBarPress {
  final int viewId;
  final int index;

  /// Which entry of the button's overflow menu was chosen, or negative when
  /// the button itself was pressed.
  final int menuIndex;

  const DuoBarPress({
    required this.viewId,
    required this.index,
    required this.menuIndex,
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

  /// Pushes a Liquid Glass capsule's contents to its native platform view.
  ///
  /// [viewId] is the id handed to `onPlatformViewCreated`. [selectedIndex] is
  /// negative for no selection, and [tint] is ARGB with 0 meaning the system
  /// label colour.
  void updateGlassCapsule(
    int viewId,
    List<String> symbols,
    int selectedIndex,
    int tint,
    bool isDark,
  );

  /// Gives the button at [buttonIndex] a real `UIMenu`, so toolbar items that
  /// do not fit the strip open in the system overflow menu instead.
  ///
  /// An empty [titles] clears the menu. Choosing an entry arrives on
  /// [glassCapsulePresses] with `menuIndex` set.
  void setGlassCapsuleMenu(
    int viewId,
    int buttonIndex,
    List<String> titles,
    List<String> symbols,
  );

  /// Button presses from every glass capsule, tagged with the view that owns
  /// them. A burst while Dart is busy rides one bridge crossing.
  @NitroStream(backpressure: Backpressure.batch)
  Stream<DuoBarPress> get glassCapsulePresses;
}
