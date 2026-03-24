#!/bin/bash
set -e

export HEX_PUBLISH=1
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="/tmp/hibana_publish"

echo "=== Publishing Hibana packages to Hex.pm ==="
echo ""

publish_app() {
  local app="$1"
  echo ">>> Publishing $app..."

  rm -rf "$WORK"
  mkdir -p "$WORK/lib"
  cp -r "$ROOT/apps/$app/lib/"* "$WORK/lib/"
  cp "$ROOT/apps/$app/mix.exs" "$WORK/mix.exs"
  [ -f "$ROOT/apps/$app/LICENSE" ] && cp "$ROOT/apps/$app/LICENSE" "$WORK/"
  [ -f "$ROOT/apps/$app/README.md" ] && cp "$ROOT/apps/$app/README.md" "$WORK/"
  [ -f "$ROOT/apps/$app/.formatter.exs" ] && cp "$ROOT/apps/$app/.formatter.exs" "$WORK/"

  cd "$WORK"
  mix deps.get
  mix hex.publish

  rm -rf "$WORK"
  echo ""
}

echo ">>> hibana core already published at https://hex.pm/packages/hibana/0.1.0"
echo "    Skipping (use 'mix hex.publish --replace' to update)"
echo ""

publish_app "hibana_plugins"
publish_app "hibana_generator"
publish_app "hibana_ecto"

echo "=== Done! ==="
