#!/bin/sh
# Draws the README screenshots into docs/images with demo presets. Nothing is sent to the mouse.
# Usage: ./scripts/make-screenshots.sh [dark|light]
set -eu

cd "$(dirname "$0")/.."

work="$(mktemp -d)"
swiftc -O -parse-as-library -emit-library -static -emit-module -module-name ZelotesKit \
    -emit-module-path "$work/ZelotesKit.swiftmodule" -o "$work/libZelotesKit.a" Sources/ZelotesKit/*.swift
app_sources="$(ls Sources/ZelotesMac/*.swift | grep -v ZelotesMacApp.swift)"
# shellcheck disable=SC2086
swiftc -O -I "$work" -L "$work" -lZelotesKit -o "$work/screenshots" scripts/screenshots/main.swift $app_sources
# The mouse photos and their button maps are read from next to the executable.
cp Support/*.svg Support/*.png "$work/"

mkdir -p docs/images
"$work/screenshots" "$(pwd)/docs/images" "$work/mappings.json" "${1:-dark}"
