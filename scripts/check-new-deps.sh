#!/usr/bin/env bash
# Fail if AI-proposed requirements introduce packages that are not allowlisted
# or are flagged as too new / unvetted for automatic merge.
#
# Talk intent: agents often "helpfully" add fresh SDKs and odd transitive deps.
# Portable for macOS Bash 3.2 (no mapfile).
set -euo pipefail

TARGET="${GUARDRAILS_TARGET:?}"
ROOT="${GUARDRAILS_ROOT:?}"
ALLOW="$ROOT/policy/dependency-allowlist.txt"
TOO_NEW="$ROOT/policy/dependency-too-new.txt"

scanning_bad_fixture=0
case "$TARGET" in
  */fixtures/bad|*/fixtures/bad/) scanning_bad_fixture=1 ;;
esac

is_listed() {
  local pkg="$1"
  local file="$2"
  local a
  [ -f "$file" ] || return 1
  while IFS= read -r a || [ -n "$a" ]; do
    case "$a" in
      ''|\#*) continue ;;
    esac
    a="$(printf '%s' "$a" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    [ "$pkg" = "$a" ] && return 0
  done <"$file"
  return 1
}

deny_file="${TMPDIR:-/tmp}/dep-deny.$$"
rm -f "$deny_file"
trap 'rm -f "$deny_file"' EXIT

req_files="$(
  if [ "$scanning_bad_fixture" -eq 1 ]; then
    find "$TARGET" -type f \( -name 'requirements.txt' -o -name 'requirements-*.txt' \)
  else
    find "$TARGET" -type f \( -name 'requirements.txt' -o -name 'requirements-*.txt' \) \
      ! -path '*/fixtures/bad/*' ! -path '*/.demo-work/*'
  fi
)"

if [ -z "$req_files" ]; then
  echo "No requirements files found — nothing to check."
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

    if is_listed "$pkg" "$TOO_NEW"; then
      echo "  DENY: $pkg (too new / unvetted for AI-generated PRs)"
      echo 1 >>"$deny_file"
      continue
    fi
    if ! is_listed "$pkg" "$ALLOW"; then
      echo "  DENY: $pkg (not on allowlist)"
      echo 1 >>"$deny_file"
      continue
    fi
    echo "  allow: $pkg"
  done <"$req"
done

if [ -f "$deny_file" ]; then
  count="$(wc -l <"$deny_file" | tr -d ' ')"
  echo "$count package(s) blocked (not allowlisted and/or too new)."
  exit 1
fi

echo "All declared packages are allowlisted and not on the too-new list."
