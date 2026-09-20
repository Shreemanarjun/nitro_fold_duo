import FlutterMacOS
import AppKit

public class SwiftNitroFoldDuoPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        NitroFoldDuoRegistry.register(NitroFoldDuoImpl())
    }
}
