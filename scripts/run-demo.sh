#!/usr/bin/env bash
# Full talk demo: agent bad proposal fails, fixed proposal passes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bold() { printf '\n\033[1m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

bold "=== Devfest Ado Ekiti 2026 — AI Code Guardrails ==="
echo "Prompt → Generate/commit (untrusted) → PR → Guardrails (scan) → Gate (enforce) → Review (approve)"

bold "1) Simulate agent PR (intentionally bad)"
./scripts/simulate-agent-pr.sh bad

bold "2) Run guardrails — expect FAIL (gate red)"
set +e
./scripts/run-guardrails.sh fixtures/bad
bad_rc=$?
set -e
if [[ "$bad_rc" -eq 0 ]]; then
  red "Unexpected: bad fixture passed. Demo is broken."
  exit 1
fi
red "Blocked (expected). Untrusted agent patch did not clear the gate."

bold "3) Simulate human-fixed / policy-compliant proposal"
./scripts/simulate-agent-pr.sh good

bold "4) Re-run guardrails — expect PASS (gate green)"
./scripts/run-guardrails.sh fixtures/good
green "Allowed (expected). Same feature, safe patterns — ready for human review."

bold "=== Demo complete ==="
echo "Next: point at .github/workflows/ai-code-guardrails.yml"
echo "Jobs: secrets → sast (CodeQL + dangerous-patterns) → deps → dockerfile"
echo "      → human-review → attest → cicd-sensor → gate"
echo "Runtime: docs/RUNTIME.md (cicd-sensor Agent in the same pipeline)"
echo "CODEOWNERS + branch protection remain the durable human approve path."
