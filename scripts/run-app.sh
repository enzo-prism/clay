#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.derivedData"

xcodebuild -workspace "$ROOT_DIR/Clay.xcworkspace" \
  -scheme Clay \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  build > "$DERIVED_DATA/build.log"

APP_PATH="$DERIVED_DATA/Build/Products/Debug/Clay.app"
if pgrep -x "Clay" >/dev/null 2>&1; then
  osascript -e 'tell application "Clay" to quit' >/dev/null 2>&1 || true
  sleep 0.6
fi

open -na "$APP_PATH"
