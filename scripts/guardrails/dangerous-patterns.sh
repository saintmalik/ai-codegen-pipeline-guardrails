#!/usr/bin/env bash
# Dangerous-pattern heuristics (eval/exec/shell=True/curl|bash).
# Used by the sast job (CI after CodeQL + local sast.sh) and as a named local check.
set -euo pipefail

TARGET="${GUARDRAILS_TARGET:?}"
ROOT="${GUARDRAILS_ROOT:?}"
PATTERNS="$ROOT/policy/dangerous-patterns.txt"

scanning_bad_fixture=0
case "$TARGET" in
  */fixtures/bad|*/fixtures/bad/) scanning_bad_fixture=1 ;;
esac

files_tmp="$(mktemp)"
trap 'rm -f "$files_tmp"' EXIT

collect_files() {
  find "$1" -type f \( \
    -name '*.py' -o -name '*.sh' -o -name '*.js' -o -name '*.ts' -o \
    -name '*.go' -o -name '*.yml' -o -name '*.yaml' -o \
    -name 'Dockerfile*' \
  \) ! -path '*/.git/*'
}

if [ "$scanning_bad_fixture" -eq 1 ]; then
  collect_files "$TARGET" >"$files_tmp"
else
  collect_files "$TARGET" \
    | grep -v '/fixtures/bad/' \
    | grep -v '/\.demo-work/' \
    | grep -v '/scripts/guardrails/' \
    >"$files_tmp" || true
fi

hits=0
while IFS= read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  # Credential shapes belong to the secrets job.
  case "$line" in
    sk_live_*|AKIA*|-----BEGIN*) continue ;;
  esac

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if grep -nE -e "$line" "$f" 2>/dev/null; then
      hits=$((hits + 1))
    fi
  done <"$files_tmp"
done <"$PATTERNS"

if [ "$hits" -gt 0 ]; then
  echo "Dangerous patterns found ($hits rule hit(s))."
  exit 1
fi

echo "No dangerous patterns matched."
