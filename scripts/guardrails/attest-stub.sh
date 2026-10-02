#!/usr/bin/env bash
# Lightweight OIDC / attestation *shape* stub for the talk.
# Does not call cloud APIs — shows the control you would wire to Actions OIDC.
set -euo pipefail

TARGET="${GUARDRAILS_TARGET:?}"
ROOT="${GUARDRAILS_ROOT:?}"

# In real CI, GITHUB_ACTIONS=true and ACTIONS_ID_TOKEN_REQUEST_URL are set.
# Locally we accept a stub attestation file the good fixture ships.
STUB="$TARGET/attestations/ci-job.intoto.jsonl"
POLICY="$ROOT/policy/attest-expected.json"

if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  echo "GitHub Actions context detected."
  echo "Would mint OIDC ID token (permissions: id-token: write) and bind"
  echo "repository claim to this job — see cicd-sensor OIDC manager-auth design."
  # Fail closed if the workflow forgot id-token permission (simulated via env).
  if [[ "${DEMO_OIDC_READY:-}" != "1" && -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]]; then
    echo "OIDC not configured for this job (DEMO_OIDC_READY / request URL missing)."
    exit 1
  fi
  echo "OIDC path OK (demo)."
  exit 0
fi

if [[ -f "$STUB" && -f "$POLICY" ]]; then
  # Minimal check: predicateType + subject name present
  if grep -q 'https://slsa.dev/provenance' "$STUB" \
    && grep -q '"name":' "$STUB"; then
    echo "Local attestation stub present and well-formed enough for demo."
    exit 0
  fi
  echo "Attestation stub malformed."
  exit 1
fi

# Bad fixture has no stub → fail, teaching "no provenance, no merge" for agent paths.
echo "Missing attestations/ci-job.intoto.jsonl (local demo stand-in for job provenance)."
echo "Good fixture includes a stub; wire real OIDC in Actions for production."
exit 1
