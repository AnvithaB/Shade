#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
mkdir -p Shade.app/Contents/MacOS .build-cache
# Some Command Line Tools installs contain two definitions of SwiftBridging.
# Hide the obsolete copy only from this compiler invocation; no system edits.
extra_flags=()
toolchain_include="$(xcode-select -p)/usr/include/swift"
if [[ -f "$toolchain_include/module.modulemap" && -f "$toolchain_include/bridging.modulemap" ]]; then
    python3 - "$toolchain_include" <<'PY'
import json, pathlib, sys
cache = pathlib.Path('.build-cache').resolve()
(cache / 'empty.modulemap').write_text('')
(cache / 'overlay.json').write_text(json.dumps({'version': 0, 'roots': [
    {'type': 'file', 'name': sys.argv[1] + '/module.modulemap',
     'external-contents': str(cache / 'empty.modulemap')}
]}))
PY
    extra_flags=(-vfsoverlay "$PWD/.build-cache/overlay.json")
fi
xcrun swiftc -parse-as-library -O -target "$(uname -m)-apple-macosx13.0" -module-cache-path "$PWD/.build-cache" "${extra_flags[@]}" Sources/Shade/Shade.swift -o Shade.app/Contents/MacOS/Shade -framework AppKit
cp Info.plist Shade.app/Contents/Info.plist
codesign --force --sign - Shade.app
echo "Shade is ready. Double-click Shade.app to launch."
