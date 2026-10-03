# Runtime CI/CD sensing vs build-time guardrails

This demo’s GitHub Actions workflow is mostly **pre-merge / build-time**: it scans the
diff and tree (secrets, CodeQL SAST, deps, Dockerfile, review label, attest stub)
before merge.

That is necessary but not sufficient. AI agents and CI jobs also **run** —
minting OIDC tokens, calling APIs, cloning repos, writing caches. Observing
that runtime behavior is a different control plane, wired here as a real job.

## Complementary layers (same pipeline)

| Layer | When | What | This repo |
|-------|------|------|-----------|
| **Build-time guardrails** | PR / before merge | Scan AI-generated code & policy gates | `ai-code-guardrails.yml` jobs + local `make demo` |
| **SAST** | Same workflow | CodeQL (`sast` job) + dangerous-patterns | Not a separate workflow |
| **Runtime CI/CD sensing** | Same workflow | cicd-sensor Agent via official Action | Job `cicd-sensor` (gate `needs` it) |

```text
  ai-code-guardrails.yml
  ┌──────────┐ ┌──────┐ ┌──────┐ ┌────────────┐ ┌──────────────┐ ┌────────┐ ┌─────────────┐
  │ secrets  │ │ sast │ │ deps │ │ dockerfile │ │ human-review │ │ attest │ │ cicd-sensor │ → gate
  │ gitleaks │ │CodeQL│ │ osv  │ │ hadolint   │ │ label        │ │ OIDC   │ │ Agent±Mgr   │
  └──────────┘ └──────┘ └──────┘ └────────────┘ └──────────────┘ └────────┘ └─────────────┘
```

## How cicd-sensor runs in this demo

Official path for GitHub-hosted runners: add
[`cicd-sensor/cicd-sensor-action`](https://github.com/cicd-sensor/cicd-sensor-action)
as the **first** step so the Agent observes the rest of the job
([docs](https://cicd-sensor.github.io/user-guide/github-hosted.html)).

| Mode | When | Behavior |
|------|------|----------|
| **Standalone (default)** | `CICD_SENSOR_MANAGER_URL` unset | Agent starts in-job; uploads `cicd-sensor-report` HTML + attestation predicate artifacts. Repo-local `.cicd-sensor/config.yaml` applies (`monitor_mode: true` for the demo). |
| **Manager delivery** | Both `CICD_SENSOR_MANAGER_URL` and `CICD_SENSOR_MANAGER_TOKEN` set | Config/rules/logs go through Manager; repo-local `.cicd-sensor/` is **ignored**. |

### Required secrets (Manager mode)

| Secret | Example | Notes |
|--------|---------|--------|
| `CICD_SENSOR_MANAGER_URL` | `https://cicd-sensor-manager.example.com` | Manager origin; do not commit |
| `CICD_SENSOR_MANAGER_TOKEN` | `sk_cs_…` | Bearer token from Manager / `cicd-sensorctl`; GitHub secret only |

The workflow job **always exists** and runs the Action. Without Manager secrets it
stays in standalone demo mode (still a real Agent run). Partial config (URL xor
token) emits a warning.

### OIDC

The `cicd-sensor` and `attest` jobs request `id-token: write` so the job is
OIDC-capable (GitHub Actions ID token). Shipping Manager auth via OIDC
(`manager-auth: oidc` style) is an evolving Manager feature — today the Action
inputs are `manager-url` + `manager-token`. When your Manager supports OIDC,
bind the same workload identity this demo already enables; see cicd-sensor
Manager docs and the project's OIDC design notes.

## What local `make demo` does *not* do

- It does **not** run CodeQL or the cicd-sensor Agent (no binaries required offline).
- Local `sast` uses dangerous-patterns (+ optional Semgrep if installed) as a
  stand-in for the CI CodeQL job.
- The `attest` local check uses fixture stub files; CI prints live job identity.

See the README table **Build-time guardrails vs Runtime CI/CD sensing**.
