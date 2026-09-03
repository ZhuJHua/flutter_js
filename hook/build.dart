import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Compiles the bundled quickjs-ng together with the `dart:ffi` bridge in `src/` into a single
/// code asset, replacing the prebuilt `.so`/`.dll`/jitpack AAR earlier versions shipped.
///
/// The asset is resolved by the `@Native` declarations in `lib/quickjs/ffi.dart`, which name it
/// through `@DefaultAsset('package:flutter_js/quickjs/ffi.dart')`.
void main(List<String> args) async {
  await build(args, (input, output) async {
    // The hook is also invoked for builds that want no code assets at all (`dart analyze`,
    // some hot-reload paths); `input.config.code` throws in those.
    if (!input.config.buildCodeAssets) return;

    final targetOS = input.config.code.targetOS;
    final isWindows = targetOS == OS.windows;
    final isAndroid = targetOS == OS.android;

    // quickjs-ng reaches for C11 `<stdatomic.h>`, which MSVC only exposes behind a switch.
    final compiler = input.config.code.cCompiler?.compiler;
    final isMsvc =
        compiler != null && compiler.pathSegments.last.toLowerCase() == 'cl.exe';

    final cbuilder = CBuilder.library(
      name: 'quickjs_c_bridge',
      assetName: 'quickjs/ffi.dart',
      language: Language.c,
      std: 'c11',
      sources: [
        'src/quickjs_dart_bridge.c',
        'src/quickjs/dtoa.c',
        'src/quickjs/libregexp.c',
        'src/quickjs/libunicode.c',
        'src/quickjs/quickjs.c',
      ],
      includes: ['src'],
      // quickjs needs libm (cos/pow/scalbn/...). It is folded into libc on macOS and glibc
      // desktops, but bionic keeps it separate, so an unlinked Android build only fails at
      // dlopen time with "cannot locate symbol scalbn".
      libraries: [
        if (!isWindows) 'm',
        if (targetOS == OS.linux) ...['dl', 'pthread'],
      ],
      defines: {
        // Makes quickjs-ng resolve `JS_LIBC_EXTERN` for an in-tree build.
        'QUICKJS_NG_BUILD': null,
        '_GNU_SOURCE': null,
        if (isWindows) ...{
          'WIN32_LEAN_AND_MEAN': null,
          '_WIN32_WINNT': '0x0601',
        },
      },
      flags: [
        if (isMsvc) '/experimental:c11atomics',
        if (!isWindows) '-funsigned-char',
        // Android 15 runs on 16 KB pages; keep the segments aligned for it.
        if (isAndroid) '-Wl,-z,max-page-size=16384',
        // Turn a missing library into a link error instead of a dlopen failure on device.
        if (isAndroid || targetOS == OS.linux) '-Wl,--no-undefined',
      ],
    );

    await cbuilder.run(
      input: input,
      output: output,
      logger: Logger('')
        ..level = Level.ALL
        ..onRecord.listen((record) => print(record.message)),
    );
  });
}
