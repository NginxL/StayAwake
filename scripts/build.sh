#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

configuration="${CONFIGURATION:-release}"
app_dir="$project_dir/dist/StayAwake.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
if [[ "${1:-}" == "--universal" ]]; then
    binaries=()
    for architecture in arm64 x86_64; do
        target="$architecture-apple-macosx14.0"
        swift build --product StayAwake -c "$configuration" --triple "$target"
        binary_dir="$(swift build -c "$configuration" --triple "$target" --show-bin-path)"
        binaries+=("$binary_dir/StayAwake")
    done
    lipo -create "${binaries[@]}" -output "$app_dir/Contents/MacOS/StayAwake"
elif [[ $# -gt 0 ]]; then
    printf 'Usage: %s [--universal]\n' "$0" >&2
    exit 2
else
    swift build --product StayAwake -c "$configuration"
    binary_dir="$(swift build -c "$configuration" --show-bin-path)"
    cp "$binary_dir/StayAwake" "$app_dir/Contents/MacOS/StayAwake"
fi
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
swift scripts/make-icon.swift "$project_dir/.build/AppIcon.iconset"
iconutil -c icns "$project_dir/.build/AppIcon.iconset" -o "$app_dir/Contents/Resources/AppIcon.icns"
cp LICENSE "$app_dir/Contents/Resources/LICENSE.txt"
cp NOTICE.md "$app_dir/Contents/Resources/NOTICE.md"
cp Resources/install-update.sh "$app_dir/Contents/Resources/install-update.sh"

# Local ad-hoc signing works without a paid Apple Developer account.
# To distribute a notarized build, supply a Developer ID identity and notarize it separately.
codesign --force --sign "${CODESIGN_IDENTITY:--}" --options runtime "$app_dir"
codesign --verify --deep --strict "$app_dir"
plutil -lint "$app_dir/Contents/Info.plist"
printf '\nBuilt: %s\n' "$app_dir"
