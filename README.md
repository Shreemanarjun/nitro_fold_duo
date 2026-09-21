# nitro_fold_duo

iPhone Duo support for Flutter: fold and camera geometry, hinge state, and the
system's vertical control bar. Bridged with [Nitro](https://pub.dev/packages/nitro)
over FFI — no method channels.

```yaml
dependencies:
  nitro_fold_duo: ^0.0.1
```

```dart
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

SignalBuilder(
  builder: (context) => Text(duoState.value.hingeStatus.name),
)
```

One import. `signals_flutter` is re-exported, so `SignalBuilder`, `signal` and
`computed` come with it.

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

## Getting started

Wrap the app once, then build screens with `DuoBarScaffold`:

```dart
import 'package:flutter/material.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    // Publishes the fold through MediaQuery, so dialogs and popups avoid it.
    builder: (context, child) => DuoDisplayFeatures(child: child!),
    home: const HomePage(),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => DuoBarScaffold(
    title: const Text('Library'),
    actions: [
      DuoBarItem(symbol: 'square.and.arrow.up', title: 'Share', onPressed: () {}),
      DuoBarItem(symbol: 'gearshape', title: 'Settings', onPressed: () {}),
    ],
    // Falls back to your normal chrome wherever bars stay horizontal.
    horizontalChrome: (context, body) =>
        Scaffold(appBar: AppBar(title: const Text('Library')), body: body),
    body: const Center(child: Text('Content')),
  );
}
```

## State

`duoState` is a signal holding the live device state. Read it inside a
`SignalBuilder` and the widget rebuilds when the device folds, rotates or
changes display.

```dart
SignalBuilder(
  builder: (context) {
    final state = duoState.value;
    return Text('${state.hingeStatus.name} · ${state.regions.length} regions');
  },
)
```

Derived signals avoid rebuilding on unrelated changes — this line does not
rebuild when a camera region moves:

```dart
SignalBuilder(builder: (context) => Text(duoHingeStatus.value.name))
```

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

### DuoState

| Field | Type | |
|---|---|---|
| `isSupported` | `bool` | Whether the device reports fold geometry at all |
| `hingeStatus` | `DuoHingeStatus` | Posture |
| `hingeAngle` | `double?` | Radians, where the sensor exists |
| `verticalBarEdge` | `DuoVerticalBarEdge` | Edge the system reserves for its bar |
| `regions` | `List<DuoReservedRegion>` | Folds and cameras, active and inactive |
| `cornerInsets` | `DuoInsets` | Display corner clearance; `.edgeInsets` converts |

A `DuoReservedRegion` has `kind` (`division` or `occlusion`), `isActive`, and
geometry read through the `rect`, `margins` and `isHorizontalBand` extensions.

**`rect`** is in Flutter logical pixels relative to the Flutter view, and
already includes `margins`. Do not inset by them again.

**Branch on `hingeStatus`, not `hingeAngle`.** No numeric range or zero
convention is documented, update rate is system policy, and requesting 135°
returns 132.5°.

## Widgets

| Widget | Description |
|---|---|
| `DuoBuilder` | Rebuilds on geometry or hinge change |
| `DuoSplit` | Places two panes either side of an active fold |
| `DuoOcclusionSafeArea` | Insets a child clear of active occlusions |
| `DuoDisplayFeatures` | Publishes fold and cameras through `MediaQuery` |
| `DuoBarScaffold` | Reserves the vertical strip and draws the bar |
| `DuoVerticalBar` | The strip itself, for a custom scaffold |
| `DuoGlassCapsule` | One `UIGlassEffect` capsule of icon buttons |
| `DuoGlassSurface` | The same material without buttons |

### DuoBuilder

The whole snapshot, without writing a `SignalBuilder`:

```dart
DuoBuilder(
  builder: (context, state) => Text(
    state.isSupported ? state.hingeStatus.name : 'not a foldable',
  ),
)
```

### DuoSplit

Places `primary` and `secondary` on opposite sides of an active fold, leaving
the reserved band empty. With no fold crossing the box they share it along
`fallbackAxis` — so this is the ordinary layout too, not something to swap in
when the phone bends.

```dart
DuoSplit(
  primary: const ArticleList(),
  secondary: const ArticleDetail(),
  fallbackAxis: Axis.horizontal,
  // Optional: draw something in the crease itself.
  band: const ColoredBox(color: Color(0x14000000)),
)
```

Keep continuously scrolling content out of it: a feed should stay stable
through the curved region rather than jump to the other pane.

### DuoOcclusionSafeArea

Insets a child clear of whatever can obscure it — on Duo, the camera. Each
region is cleared from the single cheapest edge it touches, so a corner camera
does not cost you a whole band on two sides.

```dart
DuoOcclusionSafeArea(
  minimum: const EdgeInsets.all(8),
  child: const Text('Never under the camera'),
)
```

iOS already folds some of this into the safe area. Nesting this inside a
`SafeArea` can inset twice for the same camera — use one or the other per box.

### DuoDisplayFeatures

`dart:ui` populates `MediaQuery.displayFeatures` on Android only. On iPhone Duo
it is empty, so `DisplayFeatureSubScreen` — and every dialog, popup and route
built on it — has no fold to avoid.

```dart
MaterialApp(
  builder: (context, child) => DuoDisplayFeatures(child: child!),
  home: const HomePage(),
)
```

An active division becomes a `fold` feature carrying its posture; a camera
becomes a `cutout`. Platform-reported features are preserved, so an Android
foldable keeps its own. A flat fold is reported inactive by the device and is
not published.

The pure mapping is available on its own:

```dart
final features = duoDisplayFeatures(duoState.value);
```

### DuoBarScaffold

On iPhone Duo the toolbar and tab bar move to a vertical strip at the side of
the display, as native Liquid Glass capsules. This reserves that strip, draws
the bar in it, and keeps `body` clear.

```dart
DuoBarScaffold(
  title: const Text('Library'),
  leading: DuoBarItem(
    symbol: 'chevron.backward',
    title: 'Back',
    onPressed: () => Navigator.of(context).pop(),
  ),
  actions: [
    DuoBarItem(symbol: 'square.and.arrow.up', title: 'Share', onPressed: share),
    // endsGroup starts a new capsule, keeping the pairing a toolbar would show.
    DuoBarItem(symbol: 'bookmark', title: 'Save', onPressed: save, endsGroup: true),
    DuoBarItem(symbol: 'gearshape', title: 'Settings', onPressed: settings),
  ],
  tabs: [
    DuoBarItem(symbol: 'text.justify', title: 'Read', onPressed: () => go(0)),
    DuoBarItem(symbol: 'info.circle', title: 'State', onPressed: () => go(1)),
  ],
  selectedTab: tab,
  horizontalChrome: (context, body) => Scaffold(
    appBar: AppBar(title: const Text('Library')),
    bottomNavigationBar: myTabBar,
    body: body,
  ),
  body: body,
)
```

| Parameter | |
|---|---|
| `body` | Required. Laid out clear of the strip |
| `title` | Shown at the leading edge above `body` while the strip exists |
| `leading` | Primary navigation control, placed first in the strip |
| `actions` | Toolbar items, grouped into capsules |
| `tabs`, `selectedTab` | Tab bar, drawn as one capsule at the bottom |
| `horizontalChrome` | Your normal chrome, used where there is no strip |
| `titleBackdrop` | System material behind `title`; `true` by default |
| `tint`, `style` | See [Styling](#styling) |

Where the system keeps bars horizontal — the inner display in portrait, and
every other iPhone — the strip does not exist and `horizontalChrome` draws your
ordinary app bar and tab bar around `body` instead. Omit it and `body` is used
bare.

### DuoBarItem

One icon button, named by its SF Symbol.

```dart
DuoBarItem(
  symbol: 'ellipsis',
  title: 'More',
  menu: [
    DuoBarItem(symbol: 'pencil', title: 'Edit', onPressed: edit),
    DuoBarItem(symbol: 'trash', title: 'Delete', onPressed: delete),
  ],
)
```

| Field | |
|---|---|
| `symbol` | Required. SF Symbol name, e.g. `square.and.arrow.up` |
| `title` | Accessibility label, and the wording used inside a menu |
| `onPressed` | Unused when `menu` is non-empty — the button opens the menu |
| `endsGroup` | Start a new capsule after this item |
| `menu` | Entries behind this item in a real `UIMenu` |

Items that do not fit the strip move into an overflow capsule with a real
`UIMenu`, as the system does. Room for that capsule is taken out of the budget
first, so a bar never overflows by exactly one item.

Always set `title`. An icon announces nothing on its own.

### DuoVerticalBar

The strip on its own, for a scaffold you lay out yourself. It handles status
clearance, the leading control, toolbar groups, overflow and the tab bar.

```dart
Row(
  children: [
    Expanded(child: body),
    DuoBuilder(
      builder: (context, state) => DuoVerticalBar(
        state: state,
        leading: DuoBarItem(symbol: 'chevron.backward', title: 'Back', onPressed: pop),
        actions: actions,
        tabs: tabs,
        selectedTab: tab,
      ),
    ),
  ],
)
```

### DuoGlassCapsule

A single capsule of icon buttons — the real `UIGlassEffect` material on iOS,
hosted as a platform view, and a blurred capsule of the same footprint
elsewhere. Size it yourself.

```dart
SizedBox(
  width: 52,
  height: 44.0 * items.length,
  child: DuoGlassCapsule(
    items: items,
    selectedIndex: 1,
    tint: const Color(0xFF6750A4),
    symbolPointSize: 20,
  ),
)
```

### DuoGlassSurface

The same material without buttons, for chrome that content scrolls under. It is
decorative: touches pass through to whatever sits on top.

```dart
DuoGlassSurface(
  borderRadius: 16,
  tint: const Color(0x226750A4),
  child: const Padding(
    padding: EdgeInsets.all(12),
    child: Text('Library'),
  ),
)
```

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

| Field | Controls | Default |
|---|---|---|
| `capsuleWidth` | Width of a capsule, centred in the strip | 44 |
| `itemHeight` | Height of one button inside a capsule | 44 |
| `groupSpacing` | Space between capsules | 12 |
| `edgeMargin` | Space kept from a free window edge | 24 |
| `symbolPointSize` | SF Symbol size inside a capsule | 17 |
| `stripWidth` | Overrides the system's reserved inset | system |
| `tint` | Capsule button colour | system label |
| `titleBandHeight` | Height of the leading-edge title band | 70 |
| `titlePadding` | Insets the title inside its band | `start: 20` |
| `titleBackdropRadius` | Corner radius of the material behind the title | 0 |
| `overflowSymbol`, `overflowTitle` | The overflow capsule | `ellipsis`, `More` |
| `compression` | What gives way when the strip runs out | `automatic` |

`copyWith` covers every field, so a theme can be adjusted for one screen:

```dart
DuoBarScaffold(
  style: DuoBarTheme.of(context).copyWith(tint: Colors.orange),
  body: body,
)
```

`DuoBarStyle.compression` mirrors `UIVerticalBarCompressionBehavior`
(SwiftUI: `.toolbarVerticalCompressionBehavior(.prefersToolbarItems)`):

| Value | Behaviour |
|---|---|
| `automatic`, `prefersTabBar` | Tab bar stays whole; toolbar items overflow |
| `prefersBarItems` | Toolbar keeps the strip; tab bar collapses to one button with a menu |

Other widgets take their own overrides: `DuoSplit.band` draws inside the
reserved crease, `DuoOcclusionSafeArea.minimum` sets a floor under the computed
insets, and `DuoGlassSurface` takes `borderRadius` and `tint`.

## Layout helpers

The same decisions as pure functions, for layouts the widgets do not cover.

```dart
// Where the strip is, and how wide, from the view padding.
final side = DuoLayout.barSide(MediaQuery.viewPaddingOf(context), state: state);
final width = DuoLayout.stripWidth(MediaQuery.viewPaddingOf(context));

// What to keep free at each end of the strip so controls clear the camera.
final (:top, :bottom) = DuoLayout.barInsets(
  size: MediaQuery.sizeOf(context),
  viewPadding: MediaQuery.viewPaddingOf(context),
  state: state,
);

// The band dividing a box of this size, or null if no fold crosses it.
final split = duoDivisionBand(state, const Size(400, 800));
if (split != null) {
  debugPrint('${split.horizontal ? 'top/bottom' : 'left/right'} at ${split.band}');
}

// Padding that clears the cameras out of that same box.
final insets = duoOcclusionInsets(state, const Size(400, 800));

// Which toolbar groups fit, and what moves into the overflow menu.
final fitted = duoBarOverflow(
  groups: DuoVerticalBar.groupsOf(actions),
  available: 600,
);
```

`duoDivisionBand` and `duoOcclusionInsets` take an `origin` for a box that is
not at the view's top-left. `DuoState` also carries `activeDivision`,
`activeDivisions` and `activeOcclusions` extensions.

## Testing

```sh
flutter test                 # 109 tests, 100% line coverage
```

Stage device state without hardware:

```dart
debugSetDuoState(const DuoState(
  isSupported: true,
  hingeStatus: DuoHingeStatus.partiallyOpen,
  verticalBarEdge: DuoVerticalBarEdge.trailing,
  hingeAngle: 2.2,
  regions: [
    DuoReservedRegion(
      kind: DuoRegionKind.division,
      left: 0,
      top: 380,
      width: 400,
      height: 40,
      marginLeft: 0,
      marginTop: 0,
      marginRight: 0,
      marginBottom: 0,
      isActive: true,
    ),
  ],
  cornerInsets: DuoInsets(left: 0, top: 0, right: 84, bottom: 34),
));
addTearDown(() => debugSetDuoState(null));
```

`debugSetDuoBridge` replaces the whole plugin with a fake for bridge-level
tests, and `debugClearDuoBridge` restores the real one.

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
