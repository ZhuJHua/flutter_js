package io.abner.flutter_js

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * FlutterJsPlugin
 *
 * On Android the JavaScript engine runs entirely in Dart over `dart:ffi` against the QuickJS
 * code asset built by `hook/build.dart`, so this plugin only exists to keep the
 * `io.abner.flutter_js` method channel alive for platform introspection.
 */
class FlutterJsPlugin : FlutterPlugin, MethodCallHandler {
    private var methodChannel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "io.abner.flutter_js").apply {
            setMethodCallHandler(this@FlutterJsPlugin)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
    }
}
