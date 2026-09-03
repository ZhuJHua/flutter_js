// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_js",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "flutter-js", targets: ["flutter_js"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_js",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // If your plugin requires a privacy manifest, for example if it uses any required
                // reason APIs, update the PrivacyInfo.xcprivacy file to describe your plugin's
                // privacy impact, and then uncomment these lines. For more information, see
                // https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
                // .process("PrivacyInfo.xcprivacy"),
            ],
            linkerSettings: [
                // `JavascriptCoreRuntime` resolves JavaScriptCore symbols through
                // `DynamicLibrary.process()`. iOS forbids dlopen'ing system frameworks, so the
                // framework has to be linked into the app for those symbols to be present.
                .linkedFramework("JavaScriptCore")
            ]
        )
    ]
)
