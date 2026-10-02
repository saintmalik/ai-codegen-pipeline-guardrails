#!/usr/bin/env bash
# Run all pipeline guardrails against a tree (fixtures/bad|good or a checkout).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-.}"

if [[ ! -d "$TARGET" ]]; then
  echo "usage: $0 <path-to-tree>" >&2
  exit 2
fi

# Resolve to absolute for consistent reporting
TARGET="$(cd "$TARGET" && pwd)"

export GUARDRAILS_ROOT="$ROOT"
export GUARDRAILS_TARGET="$TARGET"

echo "==> Guardrails against: $TARGET"
echo

failed=0
for check in \
  credential-scan \
  dangerous-patterns \
  dep-allowlist \
  human-review \
  attest-stub
do
  script="$ROOT/scripts/guardrails/${check}.sh"
  echo "---- ${check} ----"
  if bash "$script"; then
    echo "PASS: ${check}"
  else
    echo "FAIL: ${check}"
    failed=1
  fi
  echo
done

if [[ "$failed" -ne 0 ]]; then
  echo "==> RESULT: BLOCKED (one or more guardrails failed)"
  exit 1
fi

echo "==> RESULT: ALLOW (all guardrails passed)"
