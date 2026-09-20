import 'package:nitro/nitro.dart';

part 'nitro_fold_duo.g.dart';

@NitroModule(ios: NativeImpl.swift, android: NativeImpl.kotlin, macos: NativeImpl.swift, windows: NativeImpl.cpp, linux: NativeImpl.cpp)
abstract class NitroFoldDuo extends HybridObject {
  static final NitroFoldDuo instance = _NitroFoldDuoImpl();

  double add(double a, double b);

  @nitroAsync
  Future<String> getGreeting(String name);
}
