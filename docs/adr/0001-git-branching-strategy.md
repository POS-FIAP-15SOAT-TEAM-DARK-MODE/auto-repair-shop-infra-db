# ADR 0001 — Git branching strategy: feature → develop → main

- Status: Accepted
- Date: 2026-08-22
- Deciders: Giusier F.
- Tags: workflow, ci-cd, governance

## Context

The Tech Challenge Fase 3 brief mandates, for all 4 repositories: a protected `main`/`master` branch with no direct commits, and mandatory Pull Requests for merges. Before this decision, this repo had no branch protection at all — commits could (and did, early on) land directly on `main`.

Unlike `auto-repair-shop`, this repo has no branch-to-deploy-environment mapping — the Terraform workflow (`Infra (Terraform)`) selects `stg`/`prd` via a `workflow_dispatch` input (a Terraform workspace), independent of which git branch triggered it. So `develop` here doesn't carry the same "this merge deploys to prod" weight it does in the app repo — it exists purely for the review-staging convention.

## Decision

Adopt the same two-stage flow as the other 3 Tech Challenge repos: feature/fix branches → PR into `develop`; `develop` → PR into `main`. Both branches are GitHub branch-protected: PR required to merge, enforced even for repo admins, no force-push, no branch deletion, 0 required approvals (so solo work isn't blocked, while still keeping a PR-visible history).

## Consequences

### Positive

- Matches the brief's explicit requirement.
- Consistent convention across all 4 Tech Challenge repos.

### Negative

- Since there's no environment-mapping consequence here (unlike the app repo), the `develop`/`main` split is procedural rather than functionally load-bearing — worth remembering this repo's actual deploy target is chosen by workflow input, not branch.

## Alternatives considered

- **A. Trunk-based (feature → main directly).** Simpler, but inconsistent with the app repo's flow and the brief's general intent.

## Notes

- See `auto-repair-shop`'s ADR 0003 for the fuller rationale (this repo's version is intentionally shorter since the deploy-environment consequence doesn't apply here).
