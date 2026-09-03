# Flutter JS plugin

A Javascript engine to use with flutter. Now it is using QuickJS on Android   through Dart ffi and JavascriptCore on IOS also through dart-ffi. The Javascript runtimes runs synchronously through the dart ffi. So now you can run javascript code as a native citzen inside yours Flutter ~~Mobile~~ Apps (Android, IOS, Windows, Linux and MacOS are all supported).

In the previous versions we only get the result of evaluated expressions as String. 

**BUT NOW** we can do more with  flutter_js, like run **xhr** and **fetch** http calls through Dart http library. We are supporting **Promises** as well.

With flutter_js Flutter applications can take advantage of great javascript libraries such as ajv (json schema validation), moment (DateTime parser and operations) running natively (no PlatformChannels needed) on mobile devices, both Android and iOS.

On iOS this library relies on the native JavascriptCore provided by the iOS SDK. On Android, Windows and Linux it uses [quickjs-ng](https://github.com/quickjs-ng/quickjs), the actively maintained fork of Fabrice Bellard and Charlie Gordon's QuickJS, compiled from source that is vendored in this repository (see [How the native QuickJS library is built](#how-the-native-quickjs-library-is-built)).

To debug JS code on iOS you need to set `javascriptRuntime.setInspectable(true);` and pass sourceUrl to `evaluate` (example: sourceUrl: 'script.js').

On Android you can use JavaScriptCore instead: add the Android dependency `implementation("com.github.fast-development.android-js-runtimes:fastdev-jsruntimes-jsc:0.3.6")` (from jitpack) and pass `forceJavascriptCoreOnAndroid: true` to `getJavascriptRuntime`. That dependency only supplies JavaScriptCore; QuickJS itself is always built from source by this package.


On macOS the system JavaScriptCore is used. On Windows and Linux the engine is QuickJS. The
`dart:ffi` bindings for QuickJS were originally borrowed from
[flutter_qjs](https://pub.dev/packages/flutter_qjs) in 0.4.0 — an excellent package that did the
hard work of building a good Dart<->JS ffi bridge.

flutter_js differs in deliberately using JavaScriptCore on iOS, to avoid App Store review
problems. The guidelines allow that `Apps may contain or run code that is not embedded in the
binary (e.g. HTML5-based games, bots, etc.), as long as code distribution isn't the main purpose
of the app`, but also state `your app must use WebKit and JavaScript Core to run third-party
software and should not attempt to extend or expose native platform APIs to third-party
software` ([guidelines](https://developer.apple.com/app-store/review/guidelines/), section 4.7).
So `JavascriptRuntime` is an abstraction that runs on JavaScriptCore on Apple platforms and
QuickJS on Android, Windows and Linux.

FLutterJS allows to use Javascript to execute validations logic of TextFormField, also we can execute rule engines or redux logic shared from our web applications. The opportunities are huge.


The project is open source under MIT license. 

The bindings for use to communicate with JavascriptCore through dart:ffi we borrowed it from the package [flutter_jscore](https://pub.dev/packages/flutter_jscore).

Flutter JS provided the implementation to the QuickJS dart ffi bindings and also constructed a wrapper API to Dart which provides a unified API to evaluate javascript and communicate between Dart and Javascript through QuickJS and Javascript Core in a unified way. 

This library also allows to call xhr and fetch on Javascript through Dart Http calls. We also provide the implementation which allows to evaluate promises.


![](doc/flutter_js.png)
Flutter JS on Mobile

![](doc/macos-capture.png)
Flutter JS on Desktop


## Features:

## Installation

```yaml
dependencies:
  flutter_js: ^0.9.0
```

Requires Flutter 3.47 / Dart 3.13 or newer.

On the QuickJS platforms (Android, Windows, Linux) the engine is compiled from the sources
vendored in `src/` by a Dart [build hook](https://dart.dev/tools/hooks) the first time you build.
Nothing to configure; you just need a working host C toolchain (Xcode command line tools, the
Android NDK that Flutter already requires, Visual Studio's C++ workload, or gcc/clang).

### iOS

Uses the system JavaScriptCore; no action needed. Minimum deployment target is iOS 15.

### macOS

Uses the system JavaScriptCore; no action needed. Minimum deployment target is macOS 12.

### Android

Set the minimum Android sdk version to 24 (or higher) in your `android/app/build.gradle.kts`:

```kotlin
minSdk = 24
```

## Release Deploy

### Android

No plugin-specific configuration is required. The JavaScript engine is native code reached through
`dart:ffi`, so R8/proguard has nothing to strip on its behalf.

If you enable minification for other reasons, the standard Flutter keep rules are enough:

```proguard-rules.pro
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
```

## Examples

Here is a small flutter app showing how to evaluate javascript code inside a flutter app



```dart
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _jsResult = '';
  JavascriptRuntime flutterJs;
  @override
  void initState() {
    super.initState();
    
    flutterJs = getJavascriptRuntime();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FlutterJS Example'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('JS Evaluate Result: $_jsResult\n'),
              SizedBox(height: 20,),
              Padding(padding: EdgeInsets.all(10), child: Text('Click on the big JS Yellow Button to evaluate the expression bellow using the flutter_js plugin'),),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("Math.trunc(Math.random() * 100).toString();", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),),
              )
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.transparent, 
          child: Image.asset('assets/js.ico'),
          onPressed: () async {
            try {
              JsEvalResult jsResult = flutterJs.evaluate(
                  "Math.trunc(Math.random() * 100).toString();");
              setState(() {
                _jsResult = jsResult.stringResult;
              });
            } on PlatformException catch (e) {
              print('ERRO: ${e.details}');
            }
          },
        ),
      ),
    );
  }
}

```


**How to call dart from Javascript**

You can add a channel on `JavascriptRuntime` objects to receive calls from the Javascript engine:

In the dart side:

```dart
javascriptRuntime.onMessage('someChannelName', (dynamic args) {
     print(args);
});
```


Now, if your javascript code calls `sendMessage('someChannelName', JSON.stringify([1,2,3]);` the above dart function provided as the second argument will be called
with a List containing 1, 2, 3 as it elements.


## Alternatives (and also why we think our library is better)

There were another packages which provides alternatives to evaluate javascript in flutter projects:

### https://pub.dev/packages/flutter_liquidcore

Good, is based on https://github.com/LiquidPlayer/LiquidCore

It is based on V8 engine so the exectuable library is huge (20Mb). So the final app will be huge too.


### https://pub.dev/packages/interactive_webview

Allows to evaluate javascript in a hidden webview. Does not add weight to size of the app, but a webview means a entire browser is in memory just to evaluate javascript code. So we think an embeddable engine is a way better solution.

### https://pub.dev/packages/jsengine

Based on jerryscript which is slower than quickjs. The jsengine package does not have implementation to iOS.

### https://pub.dev/packages/flutter_jscore

Uses Javascript Core in Android and IOS. We got the JavascriptCore bindings from this amazing package. But, by
default we provides QuickJS as the javascript runtime on Android because it provides a smaller footprint. Also 
our library adds support to ConsoleLog, SetTimeout, Xhr, Fetch and Promises to be used in the scripts evaluation 
and allows your Flutter app to provide dartFunctions as channels through `onMessage` function to be called inside
your javascript code.


### https://pub.dev/packages/flutter_qjs

Amazing package which does implement the javascript engine using quickjs through Dart ffi.
The only difference is it uses quickjs also on IOS devices, which we understand would be problematic to pass Apple Store Review process. In the flutter_js 0.4.0 version, which we
added support to Desktop and also improved the Dart/Js integration, we borrowed the C function bindings and Dart/JS conversions and integrations from the flutter_qjs source code. We just adapted it to support xhr, fetch and to keep the same interface provided on flutter_js through the class JavascriptRuntime.


## Small Apk size

A hello world flutter app, according flutter docs has 4.2 Mb or 4.6 Mb in size.

https://flutter.dev/docs/perf/app-size#android


Bellow you can see the apk sizes of the `example app` generated with *flutter_js*:

```bash

|master ✓| → flutter build apk --split-per-abi

✓ Built build/app/outputs/apk/release/app-armeabi-v7a-release.apk (5.4MB).
✓ Built build/app/outputs/apk/release/app-arm64-v8a-release.apk (5.9MB).
✓ Built build/app/outputs/apk/release/app-x86_64-release.apk (6.1MB).
```


## Ajv

We just added an example of use of the amazing js library [Ajv](https://ajv.js.org/) which allow to bring state of the art json schema validation features
to the Flutter world. We can see the Ajv examples here: https://github.com/abner/flutter_js/blob/master/example/lib/ajv_example.dart 


See bellow the screens we added to the example app:

### IOS

![ios_form](doc/ios_ajv_form.png)

![ios_ajv_result](doc/ios_ajv_result.png)

### Android

![android_form](doc/android_ajv_form.png)

![android_ajv_result](doc/android_ajv_result.png)


## MACOS

* To solve `Command Line Tool - Error - xcrun: error: unable to find utility “xcodebuild”, not a developer tool or in PATH`

> sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

In Catalina with XCode 12 i needed to install ruby 2.7.2 in order to install `cocoapods` (Also needed to Flutter on IOS). So i installed `brew`and after `rbenv`.

To enable http calls, add this to your files: 

* DebugProfile.entitlements
```plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.cs.allow-jit</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
	<key>com.apple.security.network.server</key>
	<true/>
</dict>
</plist>

```

* Release.entitlements
```plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
	<key>com.apple.security.network.server</key>
	<true/>
</dict>
</plist>
```


## How the native QuickJS library is built

Everything needed to build the engine lives in this repository:

| Path | What it is |
| --- | --- |
| `src/quickjs/` | [quickjs-ng](https://github.com/quickjs-ng/quickjs) 0.16.2, vendored verbatim |
| `src/quickjs_dart_bridge.c` | The C ABI that `dart:ffi` binds to |
| `hook/build.dart` | Compiles both into one **code asset** with `package:native_toolchain_c` |

The build hook runs automatically on `flutter run`, `flutter build`, and `flutter test`, for every
target platform. There are no checked-in `.so`/`.dll` binaries and no jitpack dependency; earlier
versions of this package used both.

To move to a newer upstream release:

```bash
tool/update_quickjs.sh v0.16.3
flutter test
```

Then check that `JSTag` in `lib/quickjs/ffi.dart` still matches the tag enum in
`src/quickjs/quickjs.h` — quickjs-ng has renumbered it before.


## Unit Testing javascript evaluation

Just run `flutter test`. The build hook compiles the engine for the host before the tests run and
`dart:ffi` resolves it from the code asset, so no environment variables, prebuilt paths, or
`.vscode/launch.json` entries are needed on any platform. (Versions before 0.9.0 required
`LIBQUICKJSC_TEST_PATH` on Linux and a `PATH` entry on Windows; both are gone.)

Note that `getJavascriptRuntime()` selects JavaScriptCore on macOS hosts. To exercise QuickJS in a
test, construct it directly:

```dart
final runtime = QuickJsRuntime2();
expect(runtime.evaluate('Math.pow(5,3)').stringResult, '125');
```

See `test/quickjs_test.dart`.
