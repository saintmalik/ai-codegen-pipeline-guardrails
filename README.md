# Securing AI-Generated Code: Pipeline Guardrails for LLM and Agentic Workflows

Self-contained demo for a talk on **treating LLM/agent output as untrusted
input** and enforcing security controls in CI — before merge, not after
incident.

> No existing slides for this title were found under `presentations/` or the
> monorepo README. Framing here mirrors CI/CD sensor + agent-trust research
> interests (OIDC identity, attestation stubs, policy-as-code) without pitching
> a product.

## Talk narrative (problem → risks → guardrails → demo)

### Problem

Agents and copilots now open PRs, edit IaC, and wire deploy scripts. Speed is
real; so is the fact that **generated code bypasses the human habits that used
to catch secrets, shell pipes, and shady deps**.

### Risks (what the agent “helpfully” ships)

| Risk | Demo fixture |
|------|----------------|
| Secrets in source | Hardcoded `sk_live_…` / AWS-shaped keys |
| Dangerous runtime patterns | `eval()`, `exec()`, `subprocess(..., shell=True)` |
| Supply-chain shortcuts | `curl … \| bash` in setup scripts |
| Unvetted dependencies | Package outside the allowlist |
| Unattended merge | PR missing `security-reviewed` label |

### Guardrails (what CI must enforce)

1. **Credential scan** — fail on known key shapes in the tree  
2. **Dangerous-pattern SAST** — lightweight rules (grep/semgrep-compatible)  
3. **Dependency allowlist** — deny unknown / known-bad packages  
4. **Human review gate** — require a label before merge on `ai-generated` PRs  
5. **Optional identity stub** — OIDC/attestation shape so “who produced this
   artifact?” is not an afterthought  

Whole-repo CI skips `fixtures/bad/**` so intentional insecure samples do not
poison the green path; stage demos target that fixture explicitly.  

### Demo arc

1. Agent proposes a “helpful” patch → **guardrails red**  
2. Same feature, human-fixed → **guardrails green**  
3. Point at the GitHub Actions workflow as the durable control plane  

## Quick start

```bash
cd demos/ai-codegen-pipeline-guardrails   # or clone this repo standalone
make demo                                 # fail then pass, full story
```

Equivalent without Make:

```bash
./scripts/run-demo.sh
```

## Commands you’ll use on stage

```bash
# 1) Show the intentional bad agent proposal
./scripts/simulate-agent-pr.sh bad

# 2) Run guardrails against the bad tree (expect FAIL)
./scripts/run-guardrails.sh fixtures/bad

# 3) Apply the fixed proposal and re-check (expect PASS)
./scripts/simulate-agent-pr.sh good
./scripts/run-guardrails.sh fixtures/good

# Or one-shot narrative:
make demo
```

## Layout

```
app/                  Baseline app the agent “patches”
fixtures/bad|good/    Intentional fail/pass trees
policy/               Allowlist + pattern rules
scripts/guardrails/   Individual checks (secret, sast, deps, review, attest)
.github/workflows/    CI that mirrors the local scripts
talk/SLIDES.md        Suggested slide beats + speaker notes
```

## Design choices (talk-friendly)

- **No LLM API calls** — fixtures simulate agent output so the room is offline-safe  
- **Light deps** — bash + Python stdlib; Semgrep optional if installed  
- **Same checks locally and in Actions** — `run-guardrails.sh` is the source of truth  
- **Standalone** — copy/push this directory as its own repo when ready  

## License

Educational demo. Intentional insecure samples live only under `fixtures/bad/`.
Do not deploy them.
