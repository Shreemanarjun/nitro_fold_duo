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

The device is a signal. Read it inside a `SignalBuilder` and the widget
rebuilds when the device folds, rotates or changes display:

```dart
import 'package:nitro_fold_duo/nitro_fold_duo.dart';  // re-exports signals

SignalBuilder(
  builder: (context) {
    final state = duoState.value;
    return Text('${state.hingeStatus.name} · ${state.regions.length} regions');
  },
)
```

Narrower signals are derived, so a layout that only cares about the fold is not
rebuilt every time the hinge angle ticks:

| Signal | |
| --- | --- |
| `duoState` | the whole snapshot |
| `duoActiveDivision` | the fold currently dividing the display, or null |
| `duoActiveOcclusions` | regions that can obscure content, e.g. a camera |
| `duoHingeStatus` | `unknown` / `closed` / `partiallyOpen` / `fullyOpen` |
| `duoVerticalBarEdge` | `unspecified` / `leading` / `trailing` |

`duoState` always has a value: where there is no bridge — under `flutter test`,
or on a platform the plugin does not build for — it reports
`duoStateUnavailable` rather than throwing. The native subscription starts on
first read and is shared, so reading it from many widgets costs one stream.

`DuoReservedRegion.rect` is in Flutter logical pixels relative to the Flutter
view and **already includes** `margins` — do not inset by them again. Branch on
`hingeStatus`, not on the angle: no numeric range or zero convention is
documented, and the device reports 132.5° when asked for 135°.

### Testing against it

`debugSetDuoState` stages a pose without a device, and `debugSetDuoBridge`
swaps the whole plugin for a fake:

```dart
debugSetDuoState(DuoState(
  isSupported: true,
  hingeStatus: DuoHingeStatus.partiallyOpen,
  verticalBarEdge: DuoVerticalBarEdge.trailing,
  hingeAngle: 2.2,
  regions: [/* a division across the middle */],
));
addTearDown(() => debugSetDuoState(null));
```

## Widgets

| Widget | What it does |
| --- | --- |
| `DuoBuilder` | Rebuilds on any geometry or hinge change. |
| `DuoSplit` | Places two panes either side of an active fold, leaving the band empty; shares the box along `fallbackAxis` when no division crosses it. |
| `DuoOcclusionSafeArea` | Insets a child clear of active occlusions (the camera) from the cheapest edge. |
| `DuoBarScaffold` | Keeps the body clear of the vertical strip and draws the bar in it; falls back to `horizontalChrome` where the system keeps bars horizontal. |
| `DuoVerticalBar` | The strip itself: status clearance, back control, toolbar groups, tab bar — each group one Liquid Glass capsule, with anything that does not fit in a real `UIMenu` behind an overflow capsule. |
| `DuoGlassCapsule` | One real `UIGlassEffect` capsule, hosted as a platform view. |

`DuoLayout` exposes the same decisions as pure functions (`barSide`,
`stripWidth`, `barInsets`), and `duoBarOverflow` the fitting rule, for custom
layouts.

### Styling the bar

`DuoBarStyle` carries the measurements and tint; the defaults are what the
system uses. Pass one to a bar, or set it once with `DuoBarTheme`:

```dart
DuoBarTheme(
  style: const DuoBarStyle(capsuleWidth: 52, tint: Color(0xFF6750A4)),
  child: DuoBarScaffold(body: ...),
)
```

The strip's layout is composed in Flutter — iOS only lays out
container-managed bars vertically, never a hand-built `UINavigationBar` — while
the capsule material, its buttons and the overflow menu are genuine UIKit.
`DuoBarItem.title` becomes each button's accessibility label, so give every
action one: an icon announces nothing on its own.

## Layout

```
lib/
  nitro_fold_duo.dart                  public barrel
  src/
    nitro_fold_duo.native.dart         the Nitro spec — the only hand-written bridge file
    geometry/                          region maths, shared origin tracking
    widgets/                           DuoBuilder, DuoSplit, DuoOcclusionSafeArea
    bar/                               the vertical bar: metrics, items, capsule, scaffold
```

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

## Testing the example

Unit and widget tests cover the layout rules, which is where the real logic
lives:

```sh
flutter test
```

The bar's buttons are native, so Flutter's tester cannot reach them. The
example carries [Patrol](https://patrol.leancode.co) tests that drive them
through XCUITest:

```sh
cd example
ruby tool/setup_patrol_ios.rb   # once, and after a Patrol upgrade
DEVELOPER_DIR=/path/to/Xcode-27.1.app/Contents/Developer \
  patrol test --target integration_test/patrol_test.dart -d <duo-udid>
```

`tool/setup_patrol_ios.rb` adds the `RunnerUITests` target, links Patrol's
SwiftPM package and puts the target in the scheme — Patrol documents a
CocoaPods setup, and this example uses Swift Package Manager.

Two things to know when reading a run:

* The tests that press the bar's capsule buttons are **skipped**. XCUITest
  cannot deliver a touch to a UIKit control hosted inside a Flutter platform
  view — by accessibility element and by raw coordinate alike, the tap reports
  success and nothing happens, while real HID input works. The bar is verified
  by hand on the device instead. The tests are kept, ready for the day that is
  fixed.
* `patrol_cli` 4.7 prints `Total: 0` against Xcode 27.1's result bundles even
  when tests ran. Trust its exit code, or read the bundle:
  `xcrun xcresulttool get test-results tests --path build/ios_results_*.xcresult`.

### Fold poses

The fold itself is testable end to end. [`hinge`](https://github.com/artemnovichkov/hinge)
sets the simulator's hinge angle from the host — Xcode only exposes it as a
hidden Option-drag slider in Device Hub — and Marionette reads back what the
app made of it:

```sh
cd example
flutter run -d <duo-udid>                          # note the VM service URI
marionette register duo ws://127.0.0.1:<port>/<token>/ws
dart run tool/fold_check.dart --instance duo --device <duo-udid>
```

```
ok    0°   → closed,        466pt wide, body 382.0pt, active division false
ok    90°  → partiallyOpen, 951pt wide, body 867.0pt, active division true
ok    135° → partiallyOpen, 951pt wide, body 867.0pt, active division true
ok    180° → fullyOpen,     951pt wide, body 867.0pt, active division false
ok    0°   → closed,        466pt wide, body 382.0pt, active division false
```

That covers the pose rows of Apple's validation matrix: the cover display, both
partial angles, flat, and a round trip back. Note the flat case — at 180° the
fold is reported *inactive*, so a division only divides while the device is
actually bent.

For poking at a running app, the example initialises
[Marionette](https://pub.dev/packages/marionette_mcp) in debug builds, so an
agent can read the widget tree and drive the Flutter side:

```sh
flutter run -d <duo-udid>
marionette register duo ws://127.0.0.1:<port>/<token>/ws
marionette -i duo get-interactive-elements
```
