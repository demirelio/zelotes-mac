#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64
products="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

app="build/ZelotesMac.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Library/LaunchAgents"
cp "$products/ZelotesMac" "$app/Contents/MacOS/ZelotesMac"
cp "$products/ZelotesPointerAgent" "$app/Contents/MacOS/ZelotesPointerAgent"
cp Support/Info.plist "$app/Contents/Info.plist"
cp Support/local.zelotes-mac.pointer.plist "$app/Contents/Library/LaunchAgents/"
cp Support/*.svg Support/*.png "$app/Contents/Resources/"
# The Icon Composer icon becomes Assets.car plus AppIcon.icns for older macOS; actool comes with Xcode.
# Its paths are absolute because actool hands the work to a helper that keeps its own working directory.
root="$(pwd)"
xcrun actool "$root/Support/AppIcon.icon" --compile "$root/$app/Contents/Resources" --platform macosx \
    --minimum-deployment-target 26.0 --app-icon AppIcon --output-partial-info-plist "$root/build/AppIcon.plist" \
    > /dev/null
# Nested code has to be signed before the bundle that contains it.
codesign --force --sign - --identifier local.zelotes-mac.pointer "$app/Contents/MacOS/ZelotesPointerAgent"
codesign --force --sign - "$app"

echo "Built $app"
