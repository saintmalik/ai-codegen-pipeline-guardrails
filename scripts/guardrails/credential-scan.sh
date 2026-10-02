#!/usr/bin/env bash
# Credential-shape scan (demo heuristics — not a replacement for gitleaks/trufflehog).
set -euo pipefail

TARGET="${GUARDRAILS_TARGET:?}"
ROOT="${GUARDRAILS_ROOT:?}"
PATTERNS="$ROOT/policy/dangerous-patterns.txt"

scanning_bad_fixture=0
case "$TARGET" in
  */fixtures/bad|*/fixtures/bad/) scanning_bad_fixture=1 ;;
esac

tmp="$(mktemp)"
files_tmp="$(mktemp)"
trap 'rm -f "$tmp" "$files_tmp"' EXIT

grep -E '^(sk_live_|AKIA|-----BEGIN)' "$PATTERNS" >"$tmp" || true
if [ ! -s "$tmp" ]; then
  echo "No credential patterns configured" >&2
  exit 2
fi

# Only scan code / config that an agent would ship — not policy docs themselves.
collect_files() {
  find "$1" -type f \( \
    -name '*.py' -o -name '*.sh' -o -name '*.js' -o -name '*.ts' -o \
    -name '*.go' -o -name '*.yml' -o -name '*.yaml' -o -name '*.env' -o \
    -name '*.tf' -o -name '*.json' -o -name 'Dockerfile*' -o \
    -name 'requirements*.txt' \
  \) ! -path '*/.git/*'
}

if [ "$scanning_bad_fixture" -eq 1 ]; then
  collect_files "$TARGET" >"$files_tmp"
else
  collect_files "$TARGET" | grep -v '/fixtures/bad/' >"$files_tmp" || true
fi

hits=0
while IFS= read -r pat; do
  [ -z "$pat" ] && continue
  case "$pat" in \#*) continue ;; esac
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if grep -nE -e "$pat" "$f" 2>/dev/null; then
      hits=$((hits + 1))
    fi
  done <"$files_tmp"
done <"$tmp"

if [ "$hits" -gt 0 ]; then
  echo "Credential-like material found ($hits pattern family hit(s))."
  exit 1
fi

echo "No credential shapes matched."
