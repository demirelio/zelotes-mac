#!/bin/sh
# Builds the app and packs it into build/ZelotesMac-<version>.dmg, next to a link to Applications.
set -eu

cd "$(dirname "$0")/.."

./scripts/build-app.sh

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
stage="$(mktemp -d)"
ditto build/ZelotesMac.app "$stage/ZelotesMac.app"
ln -s /Applications "$stage/Applications"

dmg="build/ZelotesMac-$version.dmg"
rm -f "$dmg"
hdiutil create -volname "ZelotesMac $version" -srcfolder "$stage" -format UDZO -ov "$dmg" > /dev/null

echo "Built $dmg"
