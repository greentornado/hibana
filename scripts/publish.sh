#!/bin/bash
set -e

export HEX_PUBLISH=1
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="/tmp/hibana_publish"

echo "=== Publishing Hibana packages to Hex.pm ==="
echo ""

publish_app() {
  local app="$1"

  # Get version from mix.exs
  local version
  version=$(grep '@version' "$ROOT/apps/$app/mix.exs" | head -1 | sed 's/.*"\(.*\)".*/\1/')

  # Check if already published
  local replace_flag=""
  if mix hex.info "$app" "$version" &>/dev/null; then
    echo ">>> $app@$version already published — updating with --replace"
    replace_flag="--replace"
  else
    echo ">>> Publishing $app@$version (new)"
  fi

  rm -rf "$WORK"
  mkdir -p "$WORK/lib"
  cp -r "$ROOT/apps/$app/lib/"* "$WORK/lib/"
  cp "$ROOT/apps/$app/mix.exs" "$WORK/mix.exs"
  [ -f "$ROOT/apps/$app/LICENSE" ] && cp "$ROOT/apps/$app/LICENSE" "$WORK/"
  [ -f "$ROOT/apps/$app/README.md" ] && cp "$ROOT/apps/$app/README.md" "$WORK/"
  [ -f "$ROOT/apps/$app/.formatter.exs" ] && cp "$ROOT/apps/$app/.formatter.exs" "$WORK/"

  cd "$WORK"
  mix deps.get
  mix hex.publish $replace_flag

  rm -rf "$WORK"
  echo ""
}

publish_app "hibana"
publish_app "hibana_plugins"
publish_app "hibana_generator"
publish_app "hibana_ecto"

echo "=== Done! ==="
