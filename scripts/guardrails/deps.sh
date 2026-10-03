#!/usr/bin/env bash
# deps job — check-new-deps.sh + optional osv-scanner (docker/binary).
set -euo pipefail

TARGET="${GUARDRAILS_TARGET:?}"
ROOT="${GUARDRAILS_ROOT:?}"

scanning_bad_fixture=0
case "$TARGET" in
  */fixtures/bad|*/fixtures/bad/) scanning_bad_fixture=1 ;;
esac

echo "---- check-new-deps ----"
bash "$ROOT/scripts/check-new-deps.sh"

run_osv() {
  local scan_path="$1"
  # osv-scanner v2+: `scan source -r`; allow requirements.txt without a lockfile.
  if command -v osv-scanner >/dev/null 2>&1; then
    echo "osv-scanner…"
    osv-scanner scan source -r --allow-no-lockfiles "$scan_path"
    return
  fi
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo "osv-scanner via docker…"
    docker run --rm -v "$scan_path:/src:ro" \
      ghcr.io/google/osv-scanner:v2.6.0@sha256:afd838850ac1a0fcc15ff4a041dc9ba11123c3f0d2666217a5f0fcf9222b55fa \
      scan source -r --allow-no-lockfiles /src
    return
  fi
  echo "(osv-scanner not available — check-new-deps only)"
  return 0
}

echo "---- osv-scanner ----"
if [ "$scanning_bad_fixture" -eq 1 ]; then
  # Soft for fixtures: vulns vary by advisory DB; allowlist/too-new is the hard gate.
  set +e
  run_osv "$TARGET"
  osv_rc=$?
  set -e
  if [ "$osv_rc" -ne 0 ]; then
    echo "(osv findings on bad fixture — noted; check-new-deps already enforced policy)"
  fi
else
  # Whole-repo / good fixture: scan app manifests, skip intentional bad samples.
  if [ -d "$TARGET/app" ]; then
    run_osv "$TARGET/app" || {
      echo "OSV Scanner reported findings."
      exit 1
    }
  else
    run_osv "$TARGET" || {
      echo "OSV Scanner reported findings."
      exit 1
    }
  fi
fi

echo "Dependency guardrails passed."
