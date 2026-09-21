# nitro_fold_duo

iPhone Duo support for Flutter: fold and camera geometry, hinge state, and the
system's vertical control bar. Bridged with [Nitro](https://pub.dev/packages/nitro)
over FFI — no method channels.

```dart
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

SignalBuilder(
  builder: (context) => Text(duoState.value.hingeStatus.name),
)
```

## Requirements

| | |
|---|---|
| Build toolchain | Xcode 27.1 (iOS 27.1 SDK) |
| Runtime | iOS 27.1+ for fold APIs; older reports `isSupported == false` |
| Dart / Flutter | Dart 3, `signals_flutter` (re-exported) |

The reserved-region, hinge and vertical-bar APIs are introduced in 27.1 and do
not exist in earlier SDKs. They are runtime-guarded. Select the toolchain per
command rather than globally:

```sh
DEVELOPER_DIR=/path/to/Xcode-27.1.app/Contents/Developer flutter build ios --simulator
```

## Platform support

| Platform | Fold and hinge | Vertical bar |
|---|---|---|
| iOS 27.1+ | reserved regions, hinge angle, corner insets | real Liquid Glass |
| iOS < 27.1 | `isSupported == false` | — |
| Android | Jetpack WindowManager + hinge sensor | — |
| macOS, Windows, Linux | `isSupported == false` | — |

Every platform answers the whole API. Where there is no fold, state is
`duoStateUnavailable` and bar calls are accepted and ignored — no platform
checks required at the call site.

Android reports fold bounds, posture and separation through `FoldingFeature`,
emits an occlusion when the hinge occludes fully, reads `TYPE_HINGE_ANGLE`
where present, and derives corner insets from `RoundedCorner` on API 31+.
`verticalBarEdge` is always `unspecified`; Android keeps bars horizontal.

## State

`duoState` is a signal. Derived signals avoid rebuilding on unrelated changes.

| Signal | Type | Description |
|---|---|---|
| `duoState` | `DuoState` | Full snapshot |
| `duoActiveDivision` | `DuoReservedRegion?` | Fold currently dividing the display |
| `duoActiveOcclusions` | `List<DuoReservedRegion>` | Regions that can obscure content |
| `duoHingeStatus` | `DuoHingeStatus` | `unknown` · `closed` · `partiallyOpen` · `fullyOpen` |
| `duoVerticalBarEdge` | `DuoVerticalBarEdge` | `unspecified` · `leading` · `trailing` |
| `duoCornerInsets` | `EdgeInsets` | Clearance required by rounded display corners |

`duoState` always holds a value. Where no bridge exists — under `flutter test`,
or on an unsupported platform — it reports `duoStateUnavailable` rather than
throwing. The native subscription starts on first read and is shared across
listeners.

**`DuoReservedRegion.rect`** is in Flutter logical pixels relative to the
Flutter view, and already includes `margins`. Do not inset by them again.

**Branch on `hingeStatus`, not `hingeAngle`.** No numeric range or zero
convention is documented, update rate is system policy, and requesting 135°
returns 132.5°.

## Widgets

| Widget | Description |
|---|---|
| `DuoBuilder` | Rebuilds on geometry or hinge change |
| `DuoSplit` | Places two panes either side of an active fold; shares the box along `fallbackAxis` otherwise |
| `DuoOcclusionSafeArea` | Insets a child clear of active occlusions, from the cheapest edge |
| `DuoBarScaffold` | Reserves the vertical strip and draws the bar; falls back to `horizontalChrome` where bars stay horizontal |
| `DuoVerticalBar` | The strip: status clearance, back control, toolbar groups, tab bar |
| `DuoGlassCapsule` | One `UIGlassEffect` capsule, hosted as a platform view |
| `DuoGlassSurface` | The same material without buttons, for chrome content scrolls under |
| `DuoDisplayFeatures` | Publishes fold and cameras through `MediaQuery.displayFeatures` |

`DuoLayout` exposes the same decisions as pure functions — `barSide`,
`stripWidth`, `barInsets` — and `duoBarOverflow` the fitting rule, for custom
layouts.

### Display features

`dart:ui` populates `MediaQuery.displayFeatures` on Android only. On iPhone Duo
it is empty, so `DisplayFeatureSubScreen` — and every dialog, popup and route
built on it — has no fold to avoid.

```dart
MaterialApp(
  builder: (context, child) => DuoDisplayFeatures(child: child!),
)
```

An active division becomes a `fold` feature carrying its posture; a camera
becomes a `cutout`. Platform-reported features are preserved. A flat fold is
reported inactive by the device and is not published.

### The vertical bar

```dart
DuoBarScaffold(
  title: const Text('Library'),
  actions: [
    DuoBarItem(symbol: 'square.and.arrow.up', title: 'Share', onPressed: share),
    DuoBarItem(symbol: 'gearshape', title: 'Settings', onPressed: settings),
  ],
  tabs: [
    DuoBarItem(symbol: 'text.justify', title: 'Read', onPressed: () => go(0)),
    DuoBarItem(symbol: 'info.circle', title: 'State', onPressed: () => go(1)),
  ],
  selectedTab: tab,
  horizontalChrome: (context, body) => MyAppBar(body: body),
  body: body,
)
```

Each `DuoBarItem` carries its own symbol, accessibility label, menu and
callback. Items that do not fit the strip move into a real `UIMenu` behind an
overflow capsule.

`DuoBarItem.title` becomes the button's accessibility label. Always set it; an
icon announces nothing on its own.

### Styling

`DuoBarStyle` carries every measurement and tint the bar draws with, defaulting
to system values. Apply per bar, or once via `DuoBarTheme`:

```dart
DuoBarTheme(
  style: const DuoBarStyle(
    capsuleWidth: 52,
    symbolPointSize: 20,
    tint: Color(0xFF6750A4),
    titleBackdropRadius: 16,
  ),
  child: DuoBarScaffold(body: body),
)
```

| Field | Controls |
|---|---|
| `capsuleWidth`, `itemHeight`, `groupSpacing`, `edgeMargin` | Capsule geometry and spacing |
| `symbolPointSize` | SF Symbol size inside a capsule |
| `stripWidth` | Overrides the system's reserved inset |
| `tint` | Capsule button colour |
| `titleBandHeight`, `titlePadding`, `titleBackdropRadius` | The leading-edge title band |
| `overflowSymbol`, `overflowTitle` | The overflow capsule |
| `compression` | What gives way when the strip runs out |

Other widgets take their own overrides: `DuoSplit.band` draws inside the
reserved crease, `DuoOcclusionSafeArea.minimum` sets a floor under the computed
insets, and `DuoGlassSurface` takes `borderRadius` and `tint`.

`DuoBarStyle.compression` mirrors `UIVerticalBarCompressionBehavior`
(SwiftUI: `.toolbarVerticalCompressionBehavior(.prefersToolbarItems)`):

| Value | Behaviour |
|---|---|
| `automatic`, `prefersTabBar` | Tab bar stays whole; toolbar items overflow |
| `prefersBarItems` | Toolbar keeps the strip; tab bar collapses to one button with a menu |

`DuoBarScaffold` draws the system material behind the title. Pass
`titleBackdrop: false` to disable.

## Architecture

```
lib/
  nitro_fold_duo.dart            public API
  src/
    nitro_fold_duo.native.dart   Nitro spec — the only hand-written bridge file
    geometry/                    region maths, origin tracking
    widgets/                     DuoBuilder, DuoSplit, DuoOcclusionSafeArea,
                                 DuoDisplayFeatures
    bar/                         metrics, items, capsule, surface, scaffold
```

The strip's layout is composed in Flutter — iOS lays out container-managed bars
vertically, never a hand-built `UINavigationBar`. The capsule material, its
buttons and the overflow menu are UIKit.

### Bridge

Four hot-path calls — reading the snapshot, and pushing a capsule, menu or
surface — are `@nitroFast`: `isLeaf: true` bindings with no error slot,
approximately 260 ns to 13 ns. The contract is that the native side must never
throw, block, or call back into Dart; each either reads a lock-protected cached
value or hands arguments to the main thread and returns.

Presses return on one `@NitroStream(backpressure: batch)` shared by every
capsule, demultiplexed in Dart by platform view id, so a burst crosses once.

Pushes are diffed before they cross. The hinge angle ticks while the device
folds, rebuilding the bar many times a second with identical contents; a
capsule only calls the bridge when its buttons, selection, tint or symbol size
actually changed, and menus are diffed per button on top of that.

`updateGlassCapsule` is not marked `@mainThread`: on a synchronous method that
blocks the calling Dart thread until the main thread finishes.

## Testing

```sh
flutter test                 # 109 tests, 100% line coverage
```

Stage device state without hardware:

```dart
debugSetDuoState(DuoState(
  isSupported: true,
  hingeStatus: DuoHingeStatus.partiallyOpen,
  verticalBarEdge: DuoVerticalBarEdge.trailing,
  hingeAngle: 2.2,
  regions: [/* a division across the middle */],
  cornerInsets: const DuoInsets(left: 0, top: 0, right: 84, bottom: 34),
));
addTearDown(() => debugSetDuoState(null));
```

`debugSetDuoBridge` replaces the whole plugin with a fake for bridge-level
tests.

### Fold poses

[`hinge`](https://github.com/artemnovichkov/hinge) sets the simulator's hinge
angle from the host; Marionette reads back what the app made of it.

```sh
cd example
flutter run -d <duo-udid>
marionette register duo ws://127.0.0.1:<port>/<token>/ws
dart run tool/fold_check.dart --instance duo --device <duo-udid>
```

```
ok    0°   → closed,        466x678, body 382.0pt clear of a 84.0pt strip, active division false
ok    90°  → partiallyOpen, 951x669, body 867.0pt clear of a 84.0pt strip, active division true
ok    135° → partiallyOpen, 951x669, body 867.0pt clear of a 84.0pt strip, active division true
ok    180° → fullyOpen,     951x669, body 867.0pt clear of a 84.0pt strip, active division false
ok    0°   → closed,        678x466, body 594.0pt clear of a 84.0pt strip, active division false
```

Covers the pose rows of Apple's validation matrix: cover display, both partial
angles, flat, and the round trip.

### Native controls

The bar's buttons are UIKit inside a platform view. XCUITest cannot deliver
touches to them — by accessibility element or raw coordinate alike, the tap
reports success and nothing happens — so the four Patrol tests that press them
are `skip: true` and the bar is verified by hand. Two Patrol tests covering the
Flutter path do run:

```sh
cd example
ruby tool/setup_patrol_ios.rb   # once, and after a Patrol upgrade
patrol test --target integration_test/patrol_test.dart -d <duo-udid>
```

`patrol_cli` 4.7 reports `Total: 0` against Xcode 27.1 result bundles even when
tests ran. Read the bundle instead:

```sh
xcrun xcresulttool get test-results tests --path build/ios_results_*.xcresult
```

## Development

```sh
nitrogen generate   # regenerate bridges from lib/src/nitro_fold_duo.native.dart
nitrogen link       # wire them into the native build systems
```

`nitrogen link` copies hand-written Swift from `ios/Classes/` into the SPM
sources only when missing. After editing one of those files, delete the copy
under `ios/nitro_fold_duo/Sources/NitroFoldDuo/` and run `nitrogen link` again.

## Licence

MIT — see [LICENSE](LICENSE).
