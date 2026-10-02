#!/usr/bin/env bash
# Simulate an LLM/agent opening a PR by materializing a fixture into .demo-work.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VARIANT="${1:-}"

if [[ "$VARIANT" != "bad" && "$VARIANT" != "good" ]]; then
  echo "usage: $0 <bad|good>" >&2
  exit 2
fi

SRC="$ROOT/fixtures/$VARIANT"
DST="$ROOT/.demo-work"

rm -rf "$DST"
mkdir -p "$DST"
# Baseline app + agent overlay
cp -R "$ROOT/app/." "$DST/app/"
cp -R "$SRC/." "$DST/"

# Keep a pointer for talk narration
cat >"$DST/AGENT_PROPOSAL.md" <<EOF
# Simulated agent proposal ($VARIANT)

Source fixture: fixtures/$VARIANT
Author: agent-bot (offline simulation — no LLM API calls)

This tree is what CI would see after the agent pushed a branch.
EOF

echo "Materialized $VARIANT proposal -> $DST"
echo "PR meta:"
sed 's/^/  /' "$SRC/pr-meta.yaml"
