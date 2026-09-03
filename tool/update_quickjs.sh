#!/usr/bin/env bash
#
# Re-vendors quickjs-ng into src/quickjs.
#
#   tool/update_quickjs.sh v0.16.2
#
# The sources have to be checked in rather than pulled as a submodule: build hooks run from the
# consumer's pub cache, where submodules do not exist.
#
# After running this, check that `JSTag` in lib/quickjs/ffi.dart still matches the tag enum in
# src/quickjs/quickjs.h, then run `flutter test` — test/quickjs_test.dart asserts the version.
set -euo pipefail

TAG="${1:?usage: tool/update_quickjs.sh <tag, e.g. v0.16.2>}"
VERSION="${TAG#v}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/src/quickjs"

# The four translation units of the `qjs` CMake target, plus every header they include.
# quickjs-libc and the CLI are deliberately left out: the bridge does not use them.
SOURCES=(dtoa.c libregexp.c libunicode.c quickjs.c)
HEADERS=(
  builtin-array-fromasync.h builtin-iterator-zip-keyed.h builtin-iterator-zip.h
  cutils.h dtoa.h libregexp-opcode.h libregexp.h libunicode-table.h libunicode.h
  list.h quickjs-atom.h quickjs-c-atomics.h quickjs-opcode.h quickjs.h
)

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Fetching quickjs-ng $TAG ..."
curl -fsSL "https://github.com/quickjs-ng/quickjs/archive/refs/tags/$TAG.tar.gz" \
  | tar xz -C "$WORK" --strip-components=1

rm -rf "$DEST"
mkdir -p "$DEST"
for f in "${SOURCES[@]}" "${HEADERS[@]}" LICENSE; do
  cp "$WORK/$f" "$DEST/$f"
done
echo "$VERSION" > "$DEST/VERSION"

echo "Vendored quickjs-ng $VERSION into src/quickjs."
echo "Now update the expected version in test/quickjs_test.dart and run: flutter test"
