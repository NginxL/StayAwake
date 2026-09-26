#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --product PanelChecks
bin_dir=$(swift build --show-bin-path)
app_dir="$PWD/.build/PanelChecks.app"
mkdir -p "$app_dir/Contents/MacOS"
cp "$bin_dir/PanelChecks" "$app_dir/Contents/MacOS/PanelChecks"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>io.github.nginxl.StayAwake.PanelChecks</string>
  <key>CFBundleExecutable</key><string>PanelChecks</string>
  <key>CFBundleName</key><string>StayAwake UI Checks</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --sign - "$app_dir"
printf 'Launch %s in an unlocked desktop session.\nResults: .build/PanelChecks-results.json\n' "$app_dir"
