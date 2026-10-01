#!/bin/zsh
set -euo pipefail

source_dir="${0:A:h}"
# Brave uses Chrome's native messaging host directory on macOS.
host_dir="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
app_dir="$HOME/Library/Application Support/Open on iPhone"
extension_id="mmmbnkfgbegiejadoidbdcpdcdbnangg"
bundle="$source_dir/Open on iPhone.app"
binary="$bundle/Contents/MacOS/NativeHost"

if [[ ! -x "$binary" || "$source_dir/NativeHost.swift" -nt "$binary" || "$source_dir/Info.plist" -nt "$bundle/Contents/Info.plist" ]]; then
  "$source_dir/build.sh"
fi

mkdir -p "$host_dir" "$app_dir"
if [[ ! -f "$app_dir/Open on iPhone.app/Contents/MacOS/NativeHost" ]] ||
   ! cmp -s "$binary" "$app_dir/Open on iPhone.app/Contents/MacOS/NativeHost"; then
  ditto --noextattr "$bundle" "$app_dir/Open on iPhone.app"
fi
ditto --noextattr "$source_dir/extension" "$app_dir/extension"

cat > "$host_dir/local.open_on_iphone.json" <<JSON
{
  "name": "local.open_on_iphone",
  "description": "AirDrop a Brave link to Hari's iPhone",
  "path": "$app_dir/Open on iPhone.app/Contents/MacOS/NativeHost",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$extension_id/"]
}
JSON

echo "Installed Mac helper. Load the extension folder at: $app_dir/extension"
