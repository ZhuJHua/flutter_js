# 0.9.0

**Breaking.** Modernizes the plugin against Flutter 3.47 / Dart 3.13 and rebuilds how the
native engine is delivered.

### QuickJS upgraded to quickjs-ng 0.16.2 (from QuickJS 2021-03-27)

- The engine is now compiled from source vendored in `src/quickjs/`. The prebuilt
  `libquickjs_c_bridge_plugin.so` / `quickjs_c_bridge.dll` binaries and the
  `com.github.fast-development.android-js-runtimes` jitpack AAR are gone.
- Building happens in `hook/build.dart` via `package:hooks` + `package:native_toolchain_c`, so
  the library ships as a Dart **code asset**. No CMake, gradle `externalNativeBuild`, or
  checked-in binaries are involved.
- Brings ES2022-ES2024 to the QuickJS platforms: `Array.prototype.toSorted`, `findLast`,
  `Object.groupBy`, `String.prototype.at`, and much faster regexp/number handling.
- BigFloat and BigDecimal are removed upstream and are no longer available.
- `JSTag` constants were renumbered to match quickjs-ng: `FLOAT64` is now `8` (was `7`),
  `BIG_INT` is `-9`, `STRING_ROPE` (`-6`) and `SHORT_BIG_INT` (`7`) are new, and
  `BIG_FLOAT`/`BIG_DECIMAL` are gone. Code that hardcoded these values must be updated.
- New `quickJsVersion` getter reports the version of the linked engine.

### iOS and macOS migrated to Swift Package Manager

- Adds `ios/flutter_js/Package.swift` and `macos/flutter_js/Package.swift`; sources moved from
  `ios/Classes/` and `macos/Classes/` to `<platform>/flutter_js/Sources/flutter_js/`.
- The CocoaPods podspecs are kept and point at the same sources, so apps that have not migrated
  keep working.
- The Objective-C `FlutterJsPlugin` shim was removed (SwiftPM does not support mixed-language
  targets); the Swift `SwiftFlutterJsPlugin` was renamed to `FlutterJsPlugin`. `pluginClass` is
  unchanged, so this is invisible from Dart.

### Android migrated to built-in Kotlin

- `android/build.gradle` became `build.gradle.kts` and no longer applies `kotlin-android`.
  Requires AGP 9, Kotlin 2.4, Gradle 9.3.

### Other breaking changes

- Minimum Flutter 3.47 / Dart 3.13.
- Android `minSdk` 21 -> 24, `compileSdk` 34 -> 36, Java 8 -> 17.
- iOS 8.0 -> 15.0, macOS 10.11 -> 12.0.
- Removed `QuickJsRuntime` (the older `JSEvalWrapper`-based runtime) and `QuickJsService` /
  the oasis-jsbridge sync server. Both were unreachable from `getJavascriptRuntime()` and
  depended on native entry points that are no longer built. Use `QuickJsRuntime2`.
- Linux and Windows are no longer declared as plugin platforms. They never had platform code
  beyond bundling the prebuilt library, which the code asset now handles.

# 0.8.7
Fix performance issue in toUTF8 method

# 0.8.6
bumps js_android_runtime to set pagesize to comply with Google Play Store rule regarding the minimum page size of 16KB for libraries

# 0.8.5
fix memory leaks reported in https://github.com/abner/flutter_js/issues/153,
https://github.com/abner/flutter_js/issues/127

# 0.8.4
fix js_core initialization

# 0.8.3
Fix reference leaks

# 0.8.2

fix compilation issues

# 0.8.1

- fix ffi loading of JavascriptCore which failed to resolve relative path 'JavaScriptCore.framework/JavaScriptCore' in 
  MacOS and iOS, since Flutter version 3.22.0

# 0.8.0

- upgrade http dependency to ^1.0.0

# 0.7.2
- upgraded quickjs code (to allow set timeout and set maxMemory) in preparation for further improvements
- reduced the json output in the example app 

# 0.7.1
- async callback for JSC runtime
- upgraded jsc core in example app

# 0.7.0
- **Breaking**: require dart 3.0 and Flutter 3 and above
- now supports Flutter 3.10 and Dart 3.0
# 0.6.0

- **Breaking**: require dart 2.17
- **Breaking**: bump `package:ffi` to `2.0.0`

# 0.5.1

- Remove deprecated jCenter android repository in favor of mavenCentral

# 0.5.0+6

- Accepted PR [66](https://github.com/abner/flutter_js/pull/66) to return the stack
  trace into the error message from javascriptcore
- Accepted PR [#74] which prints multiples args passed into console.log
- Updated example application with new Flutter version (2.10.1)

# 0.5.0+5

- Accept PR [67](https://github.com/abner/flutter_js/pull/67) to adjust channelFunction to return the function result when using JavascriptCore on Android

# 0.5.0+4

- Accept PR [54](https://github.com/abner/flutter_js/pull/54) to adjust channelFunction to return the function result

# 0.5.0+3

- Fix the network call bug: https://github.com/abner/flutter_js/pull/57

# 0.5.0+2

- Fix the minimal stack size for 1MB for QuickJS Runtime

# 0.5.0+1

- Fix the handle_promises when the promise result is not a string

# 0.5.0+0

- Fixes issue relative to build on Dart 2.13 (issues #41 and #42)

# 0.4.0+6

- Fix executePendingJobs (wasn't dispatching in the most current version)

# 0.4.0+5

- Removed console.log from fetch.js

# 0.4.0+4

- Fixed issue on xhr requests - wasn't passing headers to the requests

# 0.4.0+3

- Fixed dynamic library load for tests
- Added info about tests into the [README.md](README.md)

# 0.4.0+2

- Updated README.md with information about github repository containing the C bridge used on
  Windows and Linux

# 0.4.0+1

- Updated README.md

# 0.4.0+0

- Added support to windows, macos and linux platforms
- Fixed fetch error
- Improved the channels/dart callback integration

# 0.3.0+0

- Null-safety migration

# 0.2.4+0

- Updated ffi, http dependencies
- Upgraded code for compatibility with ffi 1.0.0

# 0.2.3+0

- Updated QuickJS engine to version 2020-11-08
- Fix fetch

# 0.2.2+0

- Updated QuickJS engine to version 2020-09-06

# 0.2.1+0

- Updated to use QuickJS through Dart ffi instead of Platform Channel

# 0.2.0+0

- Updated to use QuickJS through PlatformChannel on Android (with this change, Android apk added size will return to be minimal )
- Change QuickJS integration to call Android platform in a sync way through http
- Added option to use JavascriptCore on Android

# 0.1.0+2

- Small fixes in the documentation on README.md

# 0.1.0+1

- Add example of onMessage (bridge which allow javascript code to call Dart)
  in the README.md

# 0.1.0+0

- Changed to use Dart FFI to call the Javascript Runtimes: QuickJS by Default in Android and JavascriptCore in iOS

# 0.0.3+1

- Updated to use a new version of oasis-jsbridge-android which brings _quickjs_ (js engine for Android)
  upgraded to the latest version (currently 2020-07-05)

# 0.0.2+1

- Upgraded to use [oasis-jsbridge-android](https://github.com/p7s1digital/oasis-jsbridge-android) library under the hood

# 0.0.1+2

- Fixed a typo in the FlutterJsPlugin.kt class

# 0.0.1+1

- Initial version only provides a very simple api which allow to init the javascript engine and evaluate javascript expressions and get the result as String.
