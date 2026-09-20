package dev.shreeman.nitro_fold_duo

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import nitro.nitro_fold_duo_module.NitroFoldDuoJniBridge

class NitroFoldDuoPlugin : FlutterPlugin, ActivityAware {

    companion object {
        init { System.loadLibrary("nitro_fold_duo") }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // registerFactory: one impl per Dart-side instance (multi-instance
        // registry). The old single-instance register(impl, context) API no
        // longer exists on the generated JniBridge.
        NitroFoldDuoJniBridge.registerFactory({ NitroFoldDuoImpl() }, binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // The generated bridge has no engine-level teardown; dropping the
        // activity is what actually needs to happen, and it stops the fold
        // listener with it.
        NitroFoldDuoJniBridge.onActivityDetached()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        NitroFoldDuoJniBridge.onActivityAttached(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        NitroFoldDuoJniBridge.onActivityDetached()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        NitroFoldDuoJniBridge.onActivityAttached(binding.activity)
    }

    override fun onDetachedFromActivity() {
        NitroFoldDuoJniBridge.onActivityDetached()
    }
}