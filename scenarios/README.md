# Scenario cards for the talk (offline — no LLM calls).

## Scenario A — Agent proposes webhook dispatcher (FAIL)

- Trigger: "Add a flexible webhook so we can plug handlers by name"
- Agent output: `fixtures/bad/`
- Findings CI should catch:
  1. Hardcoded `sk_live_…`
  2. `eval(...)` + `subprocess(..., shell=True)`
  3. `curl | bash` bootstrap
  4. `pickle5` + `openai` outside allowlist
  5. Missing `security-reviewed` label
  6. Missing job provenance stub

## Scenario B — Same feature, policy-compliant (PASS)

- Human (or constrained agent loop) rewrites to env-based secrets,
  explicit handler registry, pinned bootstrap, allowlisted deps,
  review label, attestation stub.
- Tree: `fixtures/good/`
