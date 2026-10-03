# Scenario cards (offline — no LLM calls)

## Scenario A — Agent proposes webhook dispatcher (FAIL)

- Trigger: "Add a flexible webhook so we can plug handlers by name"
- Agent output: `fixtures/bad/`
- Findings CI / local guardrails should catch:
  1. Hardcoded `sk_live_…` → **secrets** (Gitleaks)
  2. `eval(...)` + `subprocess(..., shell=True)` → **sast** (dangerous-patterns locally; CodeQL + dangerous-patterns in CI; optional Semgrep custom rules)
  3. `pickle5` + `openai` (not allowlisted / too new) → **deps**
  4. Bad `Dockerfile` (`:latest`, messy apt) → **dockerfile** (Hadolint)
  5. Missing `security-reviewed` → **human-review**
  6. Missing attestation stub → **attest**
  7. Aggregate → **gate** red
- CI also runs **cicd-sensor** (runtime Agent) on every PR; not part of the offline fixture tree.

## Scenario B — Same feature, policy-compliant (PASS)

- Human (or constrained agent loop) rewrites to env-based secrets,
  explicit handler registry, allowlisted deps, clean Dockerfile,
  `security-reviewed` label, and a local attest stub.
- Tree: `fixtures/good/`
- Gate green → durable **Review / approve** via branch protection + CODEOWNERS.

## Beyond the fixtures

- **CodeQL** is the `sast` job inside `ai-code-guardrails.yml` (not a separate workflow). Free on public GitHub; private may need Advanced Security. Not required for local `make demo`.
- **Runtime CI/CD**: job `cicd-sensor` runs [`cicd-sensor-action`](https://github.com/cicd-sensor/cicd-sensor-action) — standalone by default, Manager when secrets are set. See `docs/RUNTIME.md`.
