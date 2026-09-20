import Flutter
import UIKit

public class SwiftNitroFoldDuoPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        NitroFoldDuoRegistry.register(NitroFoldDuoImpl())
    }
}
