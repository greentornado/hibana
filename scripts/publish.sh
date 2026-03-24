#!/bin/bash
set -e

echo "=== Publishing Hibana packages to Hex.pm ==="
echo ""

export HEX_PUBLISH=1
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 1. Publish hibana (core) first
echo ">>> Publishing hibana (core)..."
cd "$ROOT/apps/hibana"
mix hex.publish
echo ""

# 2. Publish hibana_plugins
echo ">>> Publishing hibana_plugins..."
cd "$ROOT/apps/hibana_plugins"
mix hex.publish
echo ""

# 3. Publish hibana_generator
echo ">>> Publishing hibana_generator..."
cd "$ROOT/apps/hibana_generator"
mix hex.publish
echo ""

# 4. Publish hibana_ecto
echo ">>> Publishing hibana_ecto..."
cd "$ROOT/apps/hibana_ecto"
mix hex.publish
echo ""

echo "=== All packages published! ==="
echo ""
echo "Packages:"
echo "  https://hex.pm/packages/hibana"
echo "  https://hex.pm/packages/hibana_plugins"
echo "  https://hex.pm/packages/hibana_generator"
echo "  https://hex.pm/packages/hibana_ecto"
