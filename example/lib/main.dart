import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'app.dart';

void main() {
  // Marionette drives the running app over the VM service in debug builds;
  // release builds keep the ordinary binding.
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(const DuoDemoApp());
}
