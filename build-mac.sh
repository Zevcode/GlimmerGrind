#!/bin/bash
# Builds GlimmerGrind.app for macOS with the Swift command line tools.
# No Xcode required.
#
#   ./build-mac.sh             build to build/GlimmerGrind.app
#   ./build-mac.sh --install   build, then install to /Applications so
#                              Spotlight and Launchpad can find it
set -e

cd "$(dirname "$0")"
APP="build/GlimmerGrind.app"
SDK="$(xcrun --show-sdk-path --sdk macosx)"
ARCH="$(uname -m)"

echo "▸ compiling ($ARCH)"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc \
  -parse-as-library \
  -O -wmo \
  -target "${ARCH}-apple-macos14.0" \
  -sdk "$SDK" \
  -o "$APP/Contents/MacOS/GlimmerGrind" \
  $(find Sources -name '*.swift')

echo "▸ icon"
if [ ! -f "Tools/AppIcon.icns" ]; then
  swift Tools/make-icon.swift Tools/AppIcon.icns
fi
cp Tools/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Glimmer Grind</string>
    <key>CFBundleDisplayName</key><string>Glimmer Grind</string>
    <key>CFBundleExecutable</key><string>GlimmerGrind</string>
    <key>CFBundleIdentifier</key><string>com.glimmergrind.app</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.games</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticTermination</key><true/>
</dict>
</plist>
PLIST

echo "APPL????" > "$APP/Contents/PkgInfo"

echo "▸ signing (ad-hoc)"
codesign --force --sign - "$APP" 2>/dev/null || echo "  (unsigned — still runs locally)"

echo "✓ built $APP"

if [ "$1" = "--install" ]; then
  DEST="/Applications/Glimmer Grind.app"
  if [ ! -w /Applications ]; then
    DEST="$HOME/Applications/Glimmer Grind.app"
    mkdir -p "$HOME/Applications"
    echo "▸ /Applications not writable — installing to ~/Applications"
  fi
  echo "▸ installing to $DEST"
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  # Nudge Spotlight and the Launch Services database to notice it now.
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$DEST" 2>/dev/null || true
  mdimport "$DEST" 2>/dev/null || true
  echo "✓ installed — search \"Glimmer Grind\" in Spotlight (⌘Space)"
fi
