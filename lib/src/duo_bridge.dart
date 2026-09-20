import 'package:flutter/foundation.dart' show visibleForTesting;

import 'nitro_fold_duo.native.dart';

NitroFoldDuo? _override;
bool _overridden = false;

/// The native bridge, or null where there is none — under `flutter test`, and
/// on platforms the plugin does not build for.
///
/// Duo geometry is an optional capability: callers fall back rather than
/// failing, so this answers null instead of throwing.
NitroFoldDuo? get duoBridge {
  if (_overridden) return _override;
  try {
    return NitroFoldDuo.instance;
  } catch (_) {
    return null;
  }
}

/// Swaps the bridge for a fake, so the code that talks to the device can be
/// tested without one. Pass null to simulate a platform with no bridge, and
/// call [debugClearDuoBridge] to go back to the real one.
@visibleForTesting
void debugSetDuoBridge(NitroFoldDuo? bridge) {
  _override = bridge;
  _overridden = true;
}

/// Restores the real bridge after [debugSetDuoBridge].
@visibleForTesting
void debugClearDuoBridge() {
  _override = null;
  _overridden = false;
}
