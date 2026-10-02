# Slide beats — Securing AI-Generated Code

Suggested ~20–25 min arc. Each beat maps to a runnable demo step.

---

## 1. Hook (1–2 min)

**Slide:** “Your agent just opened a PR. Who reviewed the shell one-liner?”

- Agents shrink the gap between *intent* and *merged code*
- Friction that used to be human habit is now optional unless CI enforces it

**Demo cue:** show `fixtures/bad/app/src/webhook.py` headline risks (secret + eval)

---

## 2. Threat model in one box (3 min)

**Slide:** Untrusted producer → trusted pipeline → production

```
[LLM / agent] --patch--> [PR] --CI guardrails--> [human label] --> [main]
                              | fail closed
                              v
                           blocked merge
```

Claim: **AI-generated code is untrusted input.** Treat it like an external
contribution — because it is.

---

## 3. Failure modes (4 min)

**Slide table:** secret · eval/exec · curl\|bash · dep drift · auto-merge

Walk the bad fixture:

| Finding | Why it matters |
|---------|----------------|
| Hardcoded key | Agents paste from training / chat context |
| `eval` / `shell=True` | “flexible config” becomes RCE |
| `curl \| bash` | Setup scripts become supply-chain |
| Unlisted package | Lockfiles lie when agents add deps casually |
| No review label | Auto-merge + agent = silent path to prod |

**Demo:** `./scripts/run-guardrails.sh fixtures/bad` → red checks

---

## 4. Guardrail stack (5 min)

**Slide:** Defense in depth for codegen PRs

1. Secret scan (shape + entropy heuristics)  
2. Pattern SAST (dangerous APIs / shell pipes)  
3. Dependency allowlist (policy as text)  
4. Human review label / CODEOWNERS  
5. Optional OIDC/attest stub (identity of the *job*, not the model)

**Talk note:** Aligns with CI identity work (short-lived OIDC) and agent-trust
ideas (attest what ran) — without requiring those products in the room.

**Demo:** name each script under `scripts/guardrails/` as it fails

---

## 5. Live pass after fix (4 min)

**Slide:** Same feature, different patch

- Agent still “wrote” the feature (health/webhook helper)
- Secrets → env vars; eval → typed parse; curl\|bash → pinned install; deps allowlisted

**Demo:** `./scripts/simulate-agent-pr.sh good && ./scripts/run-guardrails.sh fixtures/good`

---

## 6. Make it durable in CI (3 min)

**Slide:** Local scripts == Actions jobs

Point at `.github/workflows/ai-codegen-guardrails.yml`:

- Runs on `pull_request`
- Same `run-guardrails.sh`
- Blocks on missing `security-reviewed` when the PR is labeled `ai-generated`

**Ask the room:** Where does *your* agent auth into CI today — long-lived PAT or OIDC?

---

## 7. Takeaways (2 min)

1. Generated code is untrusted input  
2. Guardrails belong in the merge path, not in a chat system prompt  
3. Policy must be machine-checkable (allowlists, labels, SAST)  
4. Identity of the pipeline job matters as much as the model that wrote the diff  

**Close:** `make demo` — fail, then pass, in under a minute.

---

## Optional appendix slides

- Semgrep rule pack vs grep heuristics (when to graduate)  
- SLSA / attestation stub: provenance for the *CI job*, not the LLM  
- AgentRust / TRACE-shaped thinking: bind tool actions to policy before merge  
- What *not* to do: “the model promised it was safe”
