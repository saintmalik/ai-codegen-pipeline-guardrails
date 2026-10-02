#!/usr/bin/env bash
# Require human security review label on AI-generated PRs.
set -euo pipefail

TARGET="${GUARDRAILS_TARGET:?}"
META="$TARGET/pr-meta.yaml"

if [[ ! -f "$META" ]]; then
  echo "No pr-meta.yaml — skipping human-review gate (non-PR tree)."
  exit 0
fi

# Tiny YAML-ish parse without pyyaml dependency.
ai="$(grep -E '^ai-generated:' "$META" | awk '{print $2}' | tr -d '"')"
if [[ "$ai" != "true" ]]; then
  echo "Not marked ai-generated; review label not required."
  exit 0
fi

if grep -E '^\s*-\s*security-reviewed\s*$' "$META" >/dev/null; then
  echo "Label security-reviewed present."
  exit 0
fi

echo "AI-generated PR missing required label: security-reviewed"
echo "Refuse auto-merge until a human attaches the label."
exit 1
