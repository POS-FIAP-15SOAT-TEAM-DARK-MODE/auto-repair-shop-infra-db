# ADR 0002 — Own the customer-login lambda's RDS-access security group here, not in its own repo

- Status: Accepted
- Date: 2026-08-22
- Deciders: Giusier F.
- Tags: infra, security-group, cross-repo, terraform

## Context

`auto-repair-shop-lambda-auth` (Fase 3 issue #4) needs its Lambda function to reach this repo's RDS instance. The natural-looking design — the lambda repo creates its own security group and this repo's RDS security group grants that SG ingress on 5432 — creates a **circular cross-repo Terraform dependency**:

- This repo (`infra-db`) already has to be applied *before* the lambda repo, because the lambda's Terraform reads `db_host` and `app_secret_arn` from this repo's remote state.
- If the lambda repo owned the security group, this repo's RDS ingress rule would need the lambda repo's `security_group_id` output — meaning this repo would need the lambda repo applied *first* instead.

Both directions can't be true at once; whichever state is meant to run first can't depend on an output from the state meant to run second.

## Decision

This repo (`infra-db`) creates a dedicated, egress-only, otherwise-empty security group (`aws_security_group.lambda_access` in `terraform/lambda_access.tf`) and adds it as a second ingress rule on the RDS security group (alongside the existing EKS-nodes-only rule), exported as output `lambda_access_security_group_id`. `auto-repair-shop-lambda-auth`'s Terraform attaches its function's `vpc_config.security_group_ids` to this pre-existing SG via `terraform_remote_state`, rather than creating its own.

This keeps the dependency graph strictly one-directional: `infra-k8s` → `infra-db` → `lambda-auth`.

## Consequences

### Positive

- No circular dependency; each state's `apply` order is unambiguous and matches the existing sequence (network → database → lambda) already established for the other cross-repo handoffs (`db_host`, `app_secret_arn`).
- The RDS security group's full ingress picture (which SGs can reach port 5432) stays visible in one file (`rds.tf`), rather than split across two repos' state.

### Negative

- Slightly counter-intuitive on first read: the lambda's own repo doesn't own its own security group. Documented inline in both `lambda_access.tf` (here) and `lambda-auth`'s `lambda.tf` (the consuming side) to make the reasoning discoverable at either end.
- Couples this repo's `lambda_access.tf` to the existence of a specific downstream consumer (the lambda) even though this repo's own job is nominally "just the database." Accepted as the smaller cost versus the alternative circular dependency.

## Alternatives considered

- **A. Lambda repo owns its own security group.** Rejected — the circular dependency described above.
- **B. A third, separate "networking glue" repo/state that both `infra-db` and `lambda-auth` depend on.** Would resolve the cycle cleanly but adds a 5th Terraform state (and likely a 5th repo, running against the Tech Challenge brief's fixed 4-repo structure) for a single security group. Disproportionate to the problem.
- **C. Skip the security group entirely; make RDS ingress open to the whole VPC CIDR.** Simpler, but weakens the "least privilege" posture the existing EKS-nodes-only rule already established — rejected on security grounds.

## Notes

- The description string on this security group caused two real deploy failures before landing: AWS's `GroupDescription` field rejects non-ASCII characters (an em dash) and rejects apostrophes, neither of which are obvious from Terraform's own validation — both are enforced only at the AWS API call itself. Worth remembering for any future SG/tag description strings in this project.
