#!/bin/bash
set -e

echo "=== Publishing Hibana packages to Hex.pm ==="
echo ""

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 1. Publish hibana (core) first — no deps on other hibana packages
echo ">>> Publishing hibana (core)..."
cd "$ROOT/apps/hibana"
mix hex.publish
echo ""

# 2. Publish hibana_plugins — depends on hibana
echo ">>> Publishing hibana_plugins..."
cd "$ROOT/apps/hibana_plugins"
mix hex.publish
echo ""

# 3. Publish hibana_generator — depends on hibana
echo ">>> Publishing hibana_generator..."
cd "$ROOT/apps/hibana_generator"
mix hex.publish
echo ""

# 4. Publish hibana_ecto — depends on hibana
echo ">>> Publishing hibana_ecto..."
cd "$ROOT/apps/hibana_ecto"
mix hex.publish
echo ""

echo "=== All packages published! ==="
echo ""
echo "Packages available at:"
echo "  https://hex.pm/packages/hibana"
echo "  https://hex.pm/packages/hibana_plugins"
echo "  https://hex.pm/packages/hibana_generator"
echo "  https://hex.pm/packages/hibana_ecto"
echo ""
echo "Docs available at:"
echo "  https://hexdocs.pm/hibana"
echo "  https://hexdocs.pm/hibana_plugins"
echo "  https://hexdocs.pm/hibana_generator"
echo "  https://hexdocs.pm/hibana_ecto"
