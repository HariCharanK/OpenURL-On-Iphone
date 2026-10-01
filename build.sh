#!/bin/zsh
set -euo pipefail

source_dir="${0:A:h}"
app="$source_dir/Open on iPhone.app"

mkdir -p "$app/Contents/MacOS"
cp "$source_dir/Info.plist" "$app/Contents/Info.plist"
swiftc -O -parse-as-library -o "$app/Contents/MacOS/NativeHost" "$source_dir/NativeHost.swift"
codesign --force --deep --sign - "$app"
