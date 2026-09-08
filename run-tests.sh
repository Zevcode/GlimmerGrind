#!/bin/bash
# Runs the headless engine tests. No Xcode, no test framework.
set -e
cd "$(dirname "$0")"

OUT="$(mktemp -d)/enginetests"
swiftc \
  -parse-as-library \
  -target "$(uname -m)-apple-macos14.0" \
  -sdk "$(xcrun --show-sdk-path --sdk macosx)" \
  -o "$OUT" \
  Sources/GlimmerGrind/Model/*.swift Tests/EngineTests.swift

"$OUT"
