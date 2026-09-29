#!/bin/bash
# Installs Godot (headless-capable editor binary) once per machine and imports the project.
# Used by the Claude Code session start hook; safe to run by hand.
set -euo pipefail
GV="${GODOT_VERSION:-4.5-stable}"
BIN="$HOME/.local/bin"
mkdir -p "$BIN"
if ! "$BIN/godot" --version >/dev/null 2>&1; then
  tmp=$(mktemp -d)
  curl -sSL -o "$tmp/g.zip" "https://github.com/godotengine/godot/releases/download/$GV/Godot_v${GV}_linux.x86_64.zip"
  unzip -q -o "$tmp/g.zip" -d "$tmp"
  mv "$tmp/Godot_v${GV}_linux.x86_64" "$BIN/godot"
  chmod +x "$BIN/godot"
  rm -rf "$tmp"
fi
cd "$(dirname "$0")/.."
"$BIN/godot" --headless --path . --import >/dev/null 2>&1 || true
echo "Godot $("$BIN/godot" --version) ready at $BIN/godot"
