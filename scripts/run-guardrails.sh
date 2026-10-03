#!/usr/bin/env bash
# Run slide guardrails + restored gates against a tree.
# Mirrors build-time jobs in .github/workflows/ai-code-guardrails.yml
# (local path needs no GitHub secrets). CodeQL + cicd-sensor are CI-only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-.}"

if [[ ! -d "$TARGET" ]]; then
  echo "usage: $0 <path-to-tree>" >&2
  exit 2
fi

TARGET="$(cd "$TARGET" && pwd)"

export GUARDRAILS_ROOT="$ROOT"
export GUARDRAILS_TARGET="$TARGET"

echo "==> Guardrails against: $TARGET"
echo "    (local: secrets → sast → deps → dockerfile → human-review → attest → gate)"
echo "    (CI also: CodeQL in sast, cicd-sensor job — not required offline)"
echo

declare -a CHECKS=(
  "credential-scan|secrets (gitleaks)"
  "sast|sast (dangerous-patterns + optional Semgrep; CodeQL is CI-only)"
  "deps|deps (allowlist/check-new-deps + osv)"
  "dockerfile|dockerfile (hadolint)"
  "human-review|human-review (security-reviewed label)"
  "attest-stub|attest (OIDC / provenance stub)"
)

failed=0
declare -a RESULTS=()
for entry in "${CHECKS[@]}"; do
  check="${entry%%|*}"
  label="${entry#*|}"
  script="$ROOT/scripts/guardrails/${check}.sh"
  echo "---- ${label} ----"
  if bash "$script"; then
    echo "PASS: ${check}"
    RESULTS+=("${check}=success")
  else
    echo "FAIL: ${check}"
    RESULTS+=("${check}=failure")
    failed=1
  fi
  echo
done

echo "---- gate (enforce) ----"
for r in "${RESULTS[@]}"; do
  echo "  $r"
done

if [[ "$failed" -ne 0 ]]; then
  echo "==> RESULT: BLOCKED (gate red — fix and push, then re-run)"
  exit 1
fi

echo "==> RESULT: ALLOW (gate green — ready for human review / approve)"
