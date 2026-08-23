# ADR 0004 — RDS metrics via a native CloudWatch dashboard, not an exporter

- Status: Accepted
- Date: 2026-08-23
- Deciders: Auto Repair Shop Team
- Tags: observability, rds, cloudwatch, tech-challenge

## Context

The Fase 3 Tech Challenge requires monitoring resource consumption as part
of its observability requirements. The Kubernetes side of this
(`auto-repair-shop-infra-k8s`) adopted a self-hosted Prometheus/Grafana/Loki
stack (see that repo's ADR 0002 and `auto-repair-shop`'s ADR 0004 for the
full reasoning against Datadog/New Relic).

RDS is a different case: it is a fully managed AWS service. AWS already
publishes `CPUUtilization`, `FreeableMemory`, `DatabaseConnections` and other
instance metrics to CloudWatch automatically, with zero agent installed and
zero extra IAM permissions beyond what already exists.

## Decision

Provision a `aws_cloudwatch_dashboard` resource (`terraform/dashboard.tf`)
named `<project>-<env>-rds`, with three widgets: CPU utilization, freeable
memory, and connection count — all reading `AWS/RDS` metrics dimensioned by
`DBInstanceIdentifier = module.rds.db_instance_identifier`. A
`cloudwatch_dashboard_url` output prints the console link after apply.

No agent (e.g. `postgres_exporter` scraped by the Prometheus in
`auto-repair-shop-infra-k8s`) is installed for this.

## Consequences

### Positive

- Zero new infrastructure: no exporter Deployment, no Prometheus scrape
  config change, no network path needed from the cluster to a database
  metrics endpoint.
- Metrics are available from the instant RDS exists — no dependency on the
  `infra-k8s` cluster/addons being up at all, which matters since this repo
  reads networking from `infra-k8s` but should not need to also depend on
  its observability stack.
- Console access is IAM-authenticated (same login every team member already
  uses for the AWS account), unlike Grafana's shared `admin`/`admin`.

### Negative

- RDS metrics live in a different UI (AWS Console) than the Kubernetes/app
  metrics (Grafana) — no single pane of glass across both. Acceptable here:
  the two are genuinely different failure domains (managed database vs.
  self-managed cluster), and cross-referencing them is not a requirement
  this challenge asks for.
- Query-level metrics (slow queries, per-query latency) are not covered —
  CloudWatch's default RDS metrics are instance-level only. Performance
  Insights would be the AWS-native answer if that granularity is ever
  needed; out of scope for the current requirement (CPU/memory/connections).

## Alternatives considered

- **A. `postgres_exporter` scraped by the `infra-k8s` Prometheus.** Would
  put RDS metrics in the same Grafana as everything else — the main
  argument for it. Rejected: requires deploying and networking an exporter
  pod against the RDS security group (widening it beyond "EKS nodes only",
  see `terraform/rds.tf`), duplicating data AWS already collects and
  publishes for free, for a database this repo does not otherwise run
  anything else against.
- **B. RDS Performance Insights.** More detail (query-level), but is a
  separate AWS feature/cost with its own UI, and the requirement here is
  satisfied by the basic instance metrics — deferred as a future
  enhancement, not needed now.

## Notes

- If query-level visibility becomes a real need later, Performance Insights
  is additive on top of this ADR (a Terraform flag on the `aws_db_instance`
  module), not a reversal of it.
