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

/// Edge insets in Flutter logical pixels.
@HybridRecord()
class DuoInsets {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const DuoInsets({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
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

  /// Which edge the system reserves for the vertical bar.
  final DuoVerticalBarEdge verticalBarEdge;

  /// Hinge angle in radians, or null when no hinge is available in this
  /// context. The update rate and precision are system policy.
  final double? hingeAngle;

  /// Every reserved region known for the Flutter view, active or not.
  final List<DuoReservedRegion> regions;

  /// The safe area widened where the display's corners are rounded, so content
  /// at a corner is not clipped by it.
  ///
  /// Flutter's own padding describes the bars and cutouts but says nothing
  /// about corner radius, and the Duo's inner display is square enough that
  /// its corners bite. Zero where the system does not report one.
  final DuoInsets cornerInsets;

  const DuoState({
    required this.isSupported,
    required this.hingeStatus,
    required this.verticalBarEdge,
    required this.hingeAngle,
    required this.regions,
    required this.cornerInsets,
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

  /// The latest snapshot. Cheap — the native side keeps it cached and
  /// recomputes it on the platform main thread when the geometry changes, so
  /// this only reads it back.
  @nitroFast
  DuoState currentState();

  /// Emits whenever the reserved regions or the hinge change.
  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<DuoState> get stateChanges;

  /// Pushes a Liquid Glass capsule's contents to its native platform view.
  ///
  /// [viewId] is the id handed to `onPlatformViewCreated`. [titles] become the
  /// buttons' accessibility labels — icon-only controls have nothing else to
  /// announce — and an empty entry leaves the label iOS derives from the SF
  /// Symbol. [selectedIndex] is negative for no selection, and [tint] is ARGB
  /// with 0 meaning the system label colour. [symbolPointSize] sizes the SF
  /// Symbols, so icons can follow a capsule that was made wider or narrower.
  ///
  /// A leaf call: the native side only hands the values to the main thread and
  /// returns, so it never throws, blocks, or calls back into Dart.
  @nitroFast
  void updateGlassCapsule(
    int viewId,
    List<String> symbols,
    List<String> titles,
    int selectedIndex,
    int tint,
    double symbolPointSize,
    bool isDark,
  );

  /// Shapes a Liquid Glass surface — the same material as the bar's capsules,
  /// without the buttons — for use behind a title or any other chrome that
  /// content scrolls under.
  ///
  /// [cornerRadius] is in logical pixels; [tint] is ARGB with 0 meaning the
  /// plain material.
  @nitroFast
  void updateGlassSurface(
    int viewId,
    double cornerRadius,
    int tint,
    bool isDark,
  );

  /// Gives the button at [buttonIndex] a real `UIMenu`, so toolbar items that
  /// do not fit the strip open in the system overflow menu instead.
  ///
  /// An empty [titles] clears the menu. Choosing an entry arrives on
  /// [glassCapsulePresses] with `menuIndex` set.
  @nitroFast
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
