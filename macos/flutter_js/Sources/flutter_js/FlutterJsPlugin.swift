import Cocoa
import FlutterMacOS

/// On macOS the JavaScript engine runs entirely in Dart over `dart:ffi` against
/// JavaScriptCore, so this plugin only exists to keep the `io.abner.flutter_js`
/// method channel alive for platform introspection.
public class FlutterJsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "io.abner.flutter_js", binaryMessenger: registrar.messenger)
    let instance = FlutterJsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
