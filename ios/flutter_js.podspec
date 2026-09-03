#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_js.podspec` to validate before publishing.
#
# This podspec is kept alongside `flutter_js/Package.swift` so the plugin keeps working for
# apps that have not migrated to Swift Package Manager yet. Both must point at the same
# sources. See https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors
#
Pod::Spec.new do |s|
  s.name             = 'flutter_js'
  s.version          = '0.9.0'
  s.summary          = 'A Javascript engine to use with flutter.'
  s.description      = <<-DESC
A Javascript engine to use with flutter. It uses QuickJS on Android, Linux and Windows,
and JavaScriptCore on iOS and macOS.
                       DESC
  s.homepage         = 'https://github.com/ZhuJHua/flutter_js'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'flutter_js' => 'https://github.com/ZhuJHua/flutter_js' }
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_js/Sources/flutter_js/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.frameworks = 'JavaScriptCore'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
