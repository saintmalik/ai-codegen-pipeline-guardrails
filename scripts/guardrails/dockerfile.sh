#!/usr/bin/env bash
# dockerfile job — hadolint when a Dockerfile exists.
set -euo pipefail

TARGET="${GUARDRAILS_TARGET:?}"

scanning_bad_fixture=0
case "$TARGET" in
  */fixtures/bad|*/fixtures/bad/) scanning_bad_fixture=1 ;;
esac

files_tmp="$(mktemp)"
trap 'rm -f "$files_tmp"' EXIT

if [ "$scanning_bad_fixture" -eq 1 ]; then
  find "$TARGET" -name Dockerfile ! -path '*/.git/*' | sort >"$files_tmp"
else
  find "$TARGET" -name Dockerfile \
    ! -path '*/fixtures/bad/*' \
    ! -path '*/.demo-work/*' \
    ! -path '*/.git/*' \
    | sort >"$files_tmp"
fi

if [ ! -s "$files_tmp" ]; then
  echo "No Dockerfile found — skip hadolint"
  exit 0
fi

hadolint_bin=""
if command -v hadolint >/dev/null 2>&1; then
  hadolint_bin="hadolint"
fi

smell_check() {
  local f="$1"
  if grep -nE 'FROM[[:space:]]+[^:]+:latest|[[:space:]]apt-get install[[:space:]]+-y[[:space:]]|ENV[[:space:]]+SECRET' "$f"; then
    echo "Dockerfile smell check failed (install hadolint or start docker for full parity)."
    return 1
  fi
  echo "(hadolint not available — basic smell check passed)"
  return 0
}

failed=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  echo "---- hadolint $f ----"
  if [ -n "$hadolint_bin" ]; then
    if ! hadolint "$f"; then
      failed=1
    fi
  elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    if ! docker run --rm -i \
      hadolint/hadolint:v2.15.1@sha256:32dac94127fd60b7b7e3fbfc65e1383b9b5e25c9bfd7b8536de7a539fe68a12d \
      <"$f"; then
      failed=1
    fi
  else
    if ! smell_check "$f"; then
      failed=1
    fi
  fi
done <"$files_tmp"

exit "$failed"
