#!/bin/bash
# Builds build/web/ (serve it with any static server, e.g. python3 -m http.server -d build/web).
# Downloads the 1.3 GB export template bundle once and keeps only the web templates.
set -euo pipefail
GV="${GODOT_VERSION:-4.5-stable}"
TV="${GV/-/.}"
TPL="$HOME/.local/share/godot/export_templates/$TV"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
if [ ! -f "$TPL/web_nothreads_release.zip" ]; then
  mkdir -p "$TPL"
  tmp=$(mktemp -d)
  curl -sSL -o "$tmp/t.tpz" "https://github.com/godotengine/godot/releases/download/$GV/Godot_v${GV}_export_templates.tpz"
  unzip -q -o -j "$tmp/t.tpz" 'templates/web_nothreads_*' 'templates/version.txt' -d "$TPL"
  rm -rf "$tmp"
fi
cd "$(dirname "$0")/.."
mkdir -p build/web
"$GODOT" --headless --path . --export-release Web build/web/index.html
