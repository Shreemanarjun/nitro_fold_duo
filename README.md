# nitro_fold_duo

iPhone Duo support for Flutter: fold and camera geometry, hinge state, and the
system's vertical control bar — over a [Nitro](https://pub.dev/packages/nitro)
FFI bridge, with no method channels.

## Requirements

Building the iOS side needs **Xcode 27.1 (iOS 27.1 SDK)**: the reserved-region,
hinge and vertical-bar APIs are introduced in 27.1 and do not exist in earlier
SDKs. They are runtime-guarded, so the plugin still runs on older systems and
reports `isSupported == false`.

Select that toolchain per command rather than globally:

```sh
DEVELOPER_DIR=/path/to/Xcode-27.1.app/Contents/Developer flutter build ios --simulator
```

## Geometry and hinge

```dart
final state = NitroFoldDuo.instance.currentState();
state.isSupported;        // the Duo APIs are available and attached to a window
state.hingeStatus;        // unknown | closed | partiallyOpen | fullyOpen
state.hingeAngle;         // radians, or null where no hinge is available
state.verticalBarEdge;    // unspecified | leading | trailing
state.regions;            // reserved regions, active and inactive

NitroFoldDuo.instance.stateChanges.listen(...);  // emits on every change
```

`DuoReservedRegion.rect` is in Flutter logical pixels relative to the Flutter
view and **already includes** `margins` — do not inset by them again. Branch on
`hingeStatus`, not on the angle: no numeric range or zero convention is
documented.

## Widgets

| Widget | What it does |
| --- | --- |
| `DuoBuilder` | Rebuilds on any geometry or hinge change. |
| `DuoSplit` | Places two panes either side of an active fold, leaving the band empty; shares the box along `fallbackAxis` when no division crosses it. |
| `DuoOcclusionSafeArea` | Insets a child clear of active occlusions (the camera) from the cheapest edge. |
| `DuoBarScaffold` | Keeps the body clear of the vertical strip and draws the bar in it; falls back to `horizontalChrome` where the system keeps bars horizontal. |
| `DuoVerticalBar` | The strip itself: status clearance, back control, toolbar groups, tab bar — each group one Liquid Glass capsule. |
| `DuoGlassCapsule` | One real `UIGlassEffect` capsule, hosted as a platform view. |

`DuoLayout` exposes the same decisions as pure functions (`barSide`,
`stripWidth`, `barInsets`) for custom layouts.

The strip's layout is composed in Flutter — iOS only lays out
container-managed bars vertically, never a hand-built `UINavigationBar` — while
the capsule material and its buttons are genuine UIKit.

## Development

```sh
nitrogen generate   # regenerate bridges from lib/src/nitro_fold_duo.native.dart
nitrogen link       # wire them into the native build systems
flutter test
```

`nitrogen link` copies hand-written Swift from `ios/Classes/` into the SPM
sources only when it is missing, so after editing one of those files delete the
copy under `ios/nitro_fold_duo/Sources/NitroFoldDuo/` and run `nitrogen link`
again.
