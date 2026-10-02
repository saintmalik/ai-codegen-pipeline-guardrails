#!/usr/bin/env bash
# Full talk demo: agent bad proposal fails, fixed proposal passes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bold() { printf '\n\033[1m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

bold "=== Demo: Securing AI-Generated Code ==="
echo "Talk beat: treat agent output as untrusted input; enforce CI guardrails."

bold "1) Simulate agent PR (intentionally bad)"
./scripts/simulate-agent-pr.sh bad

bold "2) Run pipeline guardrails — expect FAIL"
set +e
./scripts/run-guardrails.sh fixtures/bad
bad_rc=$?
set -e
if [[ "$bad_rc" -eq 0 ]]; then
  red "Unexpected: bad fixture passed. Demo is broken."
  exit 1
fi
red "Blocked (expected). Agent patch did not clear the merge gate."

bold "3) Simulate human-fixed / policy-compliant proposal"
./scripts/simulate-agent-pr.sh good

bold "4) Re-run guardrails — expect PASS"
./scripts/run-guardrails.sh fixtures/good
green "Allowed (expected). Same feature, safe patterns + review label."

bold "=== Demo complete ==="
echo "Next slide: point at .github/workflows/ai-codegen-guardrails.yml"
echo "Optional: make guardrails-bad | make guardrails-good"
