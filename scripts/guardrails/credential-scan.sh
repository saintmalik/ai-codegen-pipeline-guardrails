#!/usr/bin/env bash
# secrets job — Gitleaks (docker/binary) + credential heuristics.
set -euo pipefail

TARGET="${GUARDRAILS_TARGET:?}"
ROOT="${GUARDRAILS_ROOT:?}"
PATTERNS="$ROOT/policy/dangerous-patterns.txt"

scanning_bad_fixture=0
case "$TARGET" in
  */fixtures/bad|*/fixtures/bad/) scanning_bad_fixture=1 ;;
esac

run_gitleaks() {
  if [ "$scanning_bad_fixture" -eq 1 ]; then
    # Whole-repo .gitleaks.toml allowlists fixtures/bad; for the talk demo we
    # still want gitleaks to see the intentional finding when scanning that tree.
    if command -v gitleaks >/dev/null 2>&1; then
      echo "gitleaks detect (fixture tree, no allowlist)…"
      gitleaks detect --no-banner --source "$TARGET" --no-git --exit-code 1
      return
    fi
    if command -v docker >/dev/null 2>&1; then
      echo "gitleaks via docker (fixture tree)…"
      docker run --rm -v "$TARGET:/repo:ro" \
        zricethezav/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f \
        detect --source=/repo --no-git --verbose --exit-code=1
      return
    fi
    return 0
  fi

  # Prefer tree scan when TARGET is not the repo root (fixtures / .demo-work).
  local no_git=()
  if [ "$TARGET" != "$ROOT" ]; then
    no_git=(--no-git)
  fi

  if command -v gitleaks >/dev/null 2>&1 && [ -f "$ROOT/.gitleaks.toml" ]; then
    echo "gitleaks detect…"
    gitleaks detect --no-banner --source "$TARGET" --config "$ROOT/.gitleaks.toml" \
      "${no_git[@]}" --exit-code 1
    return
  fi
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 \
    && [ -f "$ROOT/.gitleaks.toml" ]; then
    echo "gitleaks via docker…"
    docker run --rm -v "$TARGET:/repo:ro" -v "$ROOT/.gitleaks.toml:/cfg.toml:ro" \
      zricethezav/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f \
      detect --source=/repo --config=/cfg.toml --no-git --verbose --exit-code=1
    return
  fi
  echo "(gitleaks not available — credential heuristics only)"
}

run_gitleaks || {
  echo "Gitleaks reported findings."
  exit 1
}

tmp="$(mktemp)"
files_tmp="$(mktemp)"
trap 'rm -f "$tmp" "$files_tmp"' EXIT

grep -E '^(sk_live_|AKIA|-----BEGIN)' "$PATTERNS" >"$tmp" || true
if [ ! -s "$tmp" ]; then
  echo "No credential patterns configured" >&2
  exit 2
fi

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
  collect_files "$TARGET" \
    | grep -v '/fixtures/bad/' \
    | grep -v '/\.demo-work/' \
    >"$files_tmp" || true
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
