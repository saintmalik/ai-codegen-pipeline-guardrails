# AI Code Guardrails — Devfest Ado Ekiti 2026

Self-contained demo for a **normal app** that accepts AI-generated code through
PRs, then enforces pipeline guardrails before merge.

Talk flow:

**Prompt → Generate/commit (untrusted) → PR → Guardrails (scan) → Gate (enforce) → Review (approve)**

If the gate is red: **Blocked → Fix and push → Re-run**.

## Build-time guardrails vs runtime CI/CD sensing

| Layer | Role | Where |
|-------|------|--------|
| **Build-time guardrails** (this repo) | Pre-merge scans on AI-generated code: secrets, SAST (CodeQL), deps, Dockerfile, review label, attest stub → fail-closed `gate` | `.github/workflows/ai-code-guardrails.yml` + `make demo` |
| **Runtime CI/CD sensing** ([cicd-sensor](https://github.com/cicd-sensor/cicd-sensor)) | Observes what the pipeline job **actually does** (eBPF Agent via official Action; optional Manager) | Same workflow job `cicd-sensor` — see [`docs/RUNTIME.md`](docs/RUNTIME.md) |

```text
  PR / agent patch                          Same Actions workflow
  ┌─────────────────────────┐               ┌──────────────────────────┐
  │ Build-time guardrails   │               │ Runtime CI/CD sensing    │
  │ gitleaks · CodeQL       │               │ cicd-sensor job          │
  │ dangerous-patterns      │   merge OK?   │ Agent (action) ± Manager │
  │ allowlist · osv · hadol │ ───────────►  │ OIDC-ready · artifacts   │
  │ human-review · attest   │               │                          │
  │ → gate (needs all)      │               └──────────────────────────┘
  └─────────────────────────┘
```

## Guardrails (slide: Flow, guardrail, tool)

| Job | Guardrail | Tool |
|-----|-----------|------|
| `secrets` | Secret scanning | [`gitleaks/gitleaks-action`](https://github.com/gitleaks/gitleaks-action) |
| `sast` | Static analysis + dangerous patterns | **CodeQL** (primary SAST) + `dangerous-patterns.sh`; optional Semgrep custom rules (`.semgrep/`) via Semgrep image |
| `deps` | Allowlist / unvetted deps + vulns | `check-new-deps.sh` + [`google/osv-scanner-action`](https://github.com/google/osv-scanner-action) |
| `dockerfile` | Container best practices | [`hadolint/hadolint-action`](https://github.com/hadolint/hadolint-action) (root `Dockerfile`) |
| `human-review` | Human gate for AI PRs | `security-reviewed` label when `ai-generated` + CODEOWNERS / branch protection |
| `attest` | Job identity / provenance stub | `id-token: write`, print identity, OIDC-ready stub |
| `cicd-sensor` | Runtime CI/CD observation | Official [`cicd-sensor-action`](https://github.com/cicd-sensor/cicd-sensor-action) (standalone by default; Manager when secrets set) |
| `gate` | Fail-closed aggregate | `if: always()` — red unless all jobs above succeed |

CI uses **maintainer GitHub Actions**, SHA-pinned (`uses: org/action@<sha> # vX.Y.Z`). Local `make demo` may still use CLI/Docker for offline parity.

## Quick start

```bash
cd demos/ai-codegen-pipeline-guardrails   # or clone this directory standalone
make demo                                 # bad fails, good passes
```

Same without Make:

```bash
./scripts/run-demo.sh
```

Local path needs **no GitHub secrets** and **no CodeQL / cicd-sensor binaries**.
Optional upgrades on PATH or via Docker: `gitleaks`, `semgrep`, `osv-scanner`, `hadolint`.
Heuristics still fail closed offline. CodeQL and cicd-sensor run in GitHub Actions only.

## Commands for the stage

```bash
# 1) Show the intentional bad agent proposal
./scripts/simulate-agent-pr.sh bad

# 2) Run guardrails against the bad tree (expect FAIL / gate red)
./scripts/run-guardrails.sh fixtures/bad

# 3) Apply the fixed proposal and re-check (expect PASS / gate green)
./scripts/simulate-agent-pr.sh good
./scripts/run-guardrails.sh fixtures/good

# Or one-shot:
make demo
```

## What the fixtures demonstrate

| Risk | Bad fixture | Good fixture |
|------|-------------|--------------|
| Secrets in source | Hardcoded `sk_live_…` | Env-based secret |
| Dangerous patterns | `eval()`, `subprocess(..., shell=True)` | Explicit handler map |
| Unvetted / too-new deps | `pickle5`, `openai` | Allowlisted only |
| Bad Dockerfile | `:latest`, messy `apt-get` | Pinned slim image, non-root |
| Missing human review | No `security-reviewed` label | `ai-generated` + `security-reviewed` |
| No provenance stub | Missing `attestations/` | Stub in-toto / SLSA-shaped file |

Whole-repo CI skips `fixtures/bad/**` (see `.gitleaks.toml` + job excludes) so
intentional samples do not poison the green path; stage demos target that tree
explicitly.

## Branch protection (make the gate real)

On `main`:

1. **Require a pull request before merging**
2. **Require status checks to pass** → select `gate`
3. **Require review from Code Owners** → `.github/CODEOWNERS` covers workflows / policy
4. For agent PRs: apply label `ai-generated`; humans add `security-reviewed` after review
   (the `human-review` job fails closed until that label is present)

Replace `@OWNER` in `.github/CODEOWNERS` before relying on it.

## CI secrets

| Secret | Required? | Purpose |
|--------|-----------|---------|
| `GITLEAKS_LICENSE` | **Org / Enterprise repos only** | License for [`gitleaks-action`](https://github.com/gitleaks/gitleaks-action) (free trial at [gitleaks.io](https://gitleaks.io)). **Not required** for personal-account repos. |
| `SEMGREP_APP_TOKEN` | No | Only if you connect Semgrep AppSec Platform. OSS custom rules under `.semgrep/` run without a token. |
| `CICD_SENSOR_MANAGER_URL` | No (standalone without it) | Manager base URL for config/rules + log delivery |
| `CICD_SENSOR_MANAGER_TOKEN` | With URL | Bearer token (`sk_cs_…`); store only as a GitHub secret |

`GITHUB_TOKEN` is provided automatically (gitleaks uses it for PR comments).

Without both cicd-sensor Manager secrets, the `cicd-sensor` job still runs the Agent in **standalone** mode
and uploads HTML report / attestation artifacts. See [`docs/RUNTIME.md`](docs/RUNTIME.md).

CodeQL on private repos may need GitHub Advanced Security; it is free on public repos.

### Why Actions instead of `docker run` (talk note)

Maintainer Actions give versioned inputs, PR annotations/SARIF hooks, and a smaller supply-chain surface than hand-rolled `docker run` lines (image tags, mounts, exit codes). Pinning `uses:` to a commit SHA matches the same digests story for Actions. Semgrep’s old wrapper Action is archived — current Semgrep docs use the official image, so CI follows that for optional `.semgrep/` rules only (CodeQL remains primary SAST).

## Layout

```
app/                         Baseline app the agent “patches”
fixtures/bad|good/           Intentional fail/pass trees (+ Dockerfiles, attest stub)
.semgrep/                    Optional custom/talk Semgrep rules (not primary SAST)
.cicd-sensor/                Standalone Agent config (ignored when Manager URL is set)
policy/                      Allowlist + too-new + pattern heuristics + attest expectation
scripts/check-new-deps.sh    Dependency allowlist / too-new gate
scripts/guardrails/          Local mirrors of CI jobs (+ human-review, attest-stub)
docs/RUNTIME.md              cicd-sensor job + Manager / OIDC notes
.github/workflows/
  ai-code-guardrails.yml     secrets → sast(CodeQL) → deps → dockerfile → human-review → attest → cicd-sensor → gate
Dockerfile                   Hadolint-clean root image for the app
```

## Design choices

- **No LLM API calls** — fixtures simulate agent output (offline-safe)
- **Same scans locally and in Actions** — `run-guardrails.sh` mirrors build-time jobs (CLI/Docker offline); CI uses maintainer Actions; CodeQL + cicd-sensor are CI-only
- **CodeQL is the SAST job** — Semgrep kept only for optional `.semgrep/` custom rules (official image; wrapper Action archived)
- **cicd-sensor is in the pipeline** — not docs-only; gate `needs` includes it
- **Standalone** — copy/push this directory as its own repo when ready

## License

Educational demo. Intentional insecure samples live only under `fixtures/bad/`.
Do not deploy them.
