#!/bin/bash
set -e

export HEX_PUBLISH=1
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== Publishing Hibana packages to Hex.pm ==="
echo "    (HEX_PUBLISH=1 — standalone mode, hex deps)"
echo ""

for app in hibana hibana_plugins hibana_generator hibana_ecto; do
  echo ">>> $app"
  cd "$ROOT/apps/$app"
  mix deps.get
  mix hex.publish
  echo ""
done

echo "=== Done! ==="
