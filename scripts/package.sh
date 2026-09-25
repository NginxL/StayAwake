#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
bash scripts/build.sh "$@"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
architecture="$(uname -m)"
if [[ "${1:-}" == "--universal" ]]; then architecture=universal; fi
archive="dist/StayAwake-${version}-${architecture}.zip"
ditto -c -k --sequesterRsrc --keepParent dist/StayAwake.app "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
printf 'Packaged: %s\n' "$archive"
