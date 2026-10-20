#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="$ROOT/build/PasswordProtect.app"

swift build -c release --package-path "$ROOT"
mkdir -p "$APP/Contents/MacOS"
cp "$ROOT/.build/release/PasswordProtect" "$APP/Contents/MacOS/PasswordProtect"
cp "$ROOT/App/Info.plist" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
open -na "$APP"

printf 'Built and launched: %s\n' "$APP"
