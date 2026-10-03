#!/usr/bin/env bash
# Local stand-in for the CI `sast` job.
# CI SAST is CodeQL; locally we always run dangerous-patterns, and optionally
# Semgrep custom rules under .semgrep/ when the binary/docker image is available.
# CodeQL is not required for make demo.
set -euo pipefail

TARGET="${GUARDRAILS_TARGET:?}"
ROOT="${GUARDRAILS_ROOT:?}"
SEMGREP_CFG="$ROOT/.semgrep"

scanning_bad_fixture=0
case "$TARGET" in
  */fixtures/bad|*/fixtures/bad/) scanning_bad_fixture=1 ;;
esac

run_semgrep_optional() {
  if [ ! -d "$SEMGREP_CFG" ]; then
    echo "(no .semgrep/ — skip optional custom rules)"
    return 0
  fi

  if command -v semgrep >/dev/null 2>&1; then
    echo "optional custom rules (semgrep)…"
    if [ "$scanning_bad_fixture" -eq 1 ]; then
      semgrep --quiet --error --config "$SEMGREP_CFG" "$TARGET"
    else
      semgrep --quiet --error --config "$SEMGREP_CFG" \
        --exclude 'fixtures/bad' \
        --exclude '.demo-work' \
        --exclude '.git' \
        "$TARGET"
    fi
    return
  fi

  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo "optional custom rules (semgrep via docker)…"
    if [ "$scanning_bad_fixture" -eq 1 ]; then
      docker run --rm -v "$TARGET:/src:ro" -v "$SEMGREP_CFG:/rules:ro" \
        semgrep/semgrep:1.179.0@sha256:93963d9295a366f59e4850127b1550400ee7b388f04fe144e4a1f6325d96e01b \
        semgrep scan --config /rules --error /src
    else
      docker run --rm -v "$TARGET:/src:ro" -v "$SEMGREP_CFG:/rules:ro" \
        semgrep/semgrep:1.179.0@sha256:93963d9295a366f59e4850127b1550400ee7b388f04fe144e4a1f6325d96e01b \
        semgrep scan --config /rules --error \
          --exclude fixtures/bad --exclude .demo-work --exclude .git \
          /src
    fi
    return
  fi

  echo "(semgrep not available — dangerous-patterns only; CodeQL is CI-only)"
}

run_semgrep_optional || {
  echo "Optional Semgrep custom rules reported findings."
  exit 1
}

echo "---- dangerous-patterns ----"
bash "$ROOT/scripts/guardrails/dangerous-patterns.sh"
