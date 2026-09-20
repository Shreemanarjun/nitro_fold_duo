import Flutter
import UIKit

public class SwiftNitroFoldDuoPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        NitroFoldDuoRegistry.register(NitroFoldDuoImpl())
        // The capsule is configured over the Nitro FFI bridge, not a channel,
        // so the factory needs no binary messenger.
        registrar.register(DuoGlassCapsuleFactory(), withId: "nitro_fold_duo/glass_capsule")
        registrar.register(DuoGlassSurfaceFactory(), withId: "nitro_fold_duo/glass_surface")
    }
}
