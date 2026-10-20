#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT="$ROOT/.build/FolderPINSmokeTest"

mkdir -p "$ROOT/.build"
swiftc -swift-version 6 \
    "$ROOT/Sources/PasswordProtect/FolderPINService.swift" \
    "$ROOT/Tests/FolderPINSmokeTest.swift" \
    -o "$OUTPUT"
"$OUTPUT"
