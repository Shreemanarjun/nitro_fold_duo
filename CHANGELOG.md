## 0.0.1

Initial release: iPhone Duo support, over a Nitro FFI bridge with no method
channels.

**Geometry and hinge**

* `duoState` and the derived `duoActiveDivision`, `duoActiveOcclusions`,
  `duoHingeStatus`, `duoVerticalBarEdge` and `duoCornerInsets` signals report
  the fold, the cameras, the hinge and the corner clearance, and rebuild a
  widget when the device folds, rotates or changes display.
* `DuoSplit` places two panes either side of an active fold, `DuoOcclusionSafeArea`
  keeps content clear of a camera, and `DuoLayout` exposes the same decisions as
  pure functions for custom layouts.
* `DuoDisplayFeatures` publishes the fold through `MediaQuery.displayFeatures`,
  which `dart:ui` only fills in on Android — so dialogs, popups and routes that
  already avoid a hinge on a Fold behave the same on iPhone Duo.

**The vertical bar**

* `DuoBarScaffold` keeps the body clear of the strip the system reserves and
  draws the bar in it, falling back to your own horizontal chrome where the
  system keeps bars horizontal.
* `DuoVerticalBar` lays the strip out the way the system does: status
  clearance, back control, toolbar groups and the tab bar, each group one real
  `UIGlassEffect` capsule, with anything that does not fit behind a `UIMenu`.
* `DuoBarStyle` and `DuoBarTheme` carry the measurements and tint;
  `DuoBarStyle.compression` mirrors `UIVerticalBarCompressionBehavior`.
* `DuoGlassSurface` is the same material without the buttons, for chrome that
  content scrolls under.

**Platforms**

* iOS 27.1 for the reserved-region, hinge and vertical-bar APIs; older systems
  report `isSupported == false`.
* Android reports the fold through Jetpack WindowManager and the hinge angle
  through the hinge sensor.
* macOS, Windows and Linux answer the whole API as "no Duo" and ignore the bar
  calls, so an app can call it without a platform check.
