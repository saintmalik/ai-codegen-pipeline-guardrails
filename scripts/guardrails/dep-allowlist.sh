#!/usr/bin/env bash
# Fail if requirements*.txt names packages outside the allowlist.
# Portable for macOS Bash 3.2 (no mapfile).
set -euo pipefail

TARGET="${GUARDRAILS_TARGET:?}"
ROOT="${GUARDRAILS_ROOT:?}"
ALLOW="$ROOT/policy/dependency-allowlist.txt"

scanning_bad_fixture=0
case "$TARGET" in
  */fixtures/bad|*/fixtures/bad/) scanning_bad_fixture=1 ;;
esac

is_allowed() {
  local pkg="$1"
  local a
  while IFS= read -r a || [ -n "$a" ]; do
    case "$a" in
      ''|\#*) continue ;;
    esac
    a="$(printf '%s' "$a" | tr '[:upper:]' '[:lower:]')"
    [ "$pkg" = "$a" ] && return 0
  done <"$ALLOW"
  return 1
}

deny_file="${TMPDIR:-/tmp}/dep-deny.$$"
rm -f "$deny_file"

req_files="$(
  if [ "$scanning_bad_fixture" -eq 1 ]; then
    find "$TARGET" -type f \( -name 'requirements.txt' -o -name 'requirements-*.txt' \)
  else
    find "$TARGET" -type f \( -name 'requirements.txt' -o -name 'requirements-*.txt' \) ! -path '*/fixtures/bad/*'
  fi
)"

if [ -z "$req_files" ]; then
  echo "No requirements files found — nothing to allowlist-check."
  exit 0
fi

echo "$req_files" | while IFS= read -r req; do
  [ -z "$req" ] && continue
  echo "Checking $req"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|\#*) continue ;;
    esac
    pkg="$(printf '%s' "$line" | sed -E 's/[[:space:]]+//g; s/[<>=!~].*$//; s/\[.*\]//; s/#.*//')"
    pkg="$(printf '%s' "$pkg" | tr '[:upper:]' '[:lower:]')"
    [ -z "$pkg" ] && continue
    if ! is_allowed "$pkg"; then
      echo "  DENY: $pkg (from: $line)"
      echo 1 >>"$deny_file"
    else
      echo "  allow: $pkg"
    fi
  done <"$req"
done

if [ -f "$deny_file" ]; then
  count="$(wc -l <"$deny_file" | tr -d ' ')"
  rm -f "$deny_file"
  echo "$count package(s) outside allowlist."
  exit 1
fi

echo "All declared packages are allowlisted."
