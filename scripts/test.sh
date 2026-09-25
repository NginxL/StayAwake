#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Uses a plain Swift executable so Xcode's XCTest bundle is not required.
swift run AwakeChecks "$@"
