# ADR 0006 — DynamoDB for the History & Reporting service

- Status: Accepted
- Date: 2026-11-01
- Deciders: Auto Repair Shop Team
- Tags: database, dynamodb, history, data-model

## Context

The History & Reporting service records events from the other services (status
changes, payments, stock movements) and answers reporting queries over them. Its
data has these characteristics:

- It is append-only: events are written once and rarely updated.
- Access is by key: a service and a time range, or an order identifier.
- It has no relational joins with the other services' data, which the services
  keep in their own databases (ADR 0005).
- Write volume follows the events of the whole system and can spike.

ADR 0003 chose PostgreSQL as the engine for the relational data of the core
services and rejected a NoSQL store for that data. This ADR does not change that
decision. It covers only the History service's event store.

## Decision

Store the History events in one DynamoDB table, `auto-repair-shop-<env>-history`,
managed by its own Terraform state (`terraform/dynamodb/`, key
`dynamodb/terraform.tfstate`):

- Primary key: `PK` (string, partition) and `SK` (string, sort). The item model
  (which `PK`/`SK` patterns each event uses) belongs to the History service.
- `billing_mode = PAY_PER_REQUEST`: no capacity planning, and cost follows the
  actual traffic.
- `point_in_time_recovery` and `deletion_protection_enabled` are on only in `prd`.
  In `stg` the table can be recreated freely.
- The service gets the table name through `DYNAMODB_TABLE`. The physical name is
  never hard-coded.
- The table is in its own state, so it can be applied and destroyed without
  touching the RDS state.

## Consequences

### Positive

- Write throughput scales without provisioning, and the cost is per request.
- Key-based access is the natural access pattern for event history.
- The table is independent of the RDS instance: no connection pool, no
  maintenance window, and no load on the relational databases from event writes.
- The CI can check the table without AWS: the `dynamodb-ministack` job applies it
  against MiniStack.

### Negative

- Only key-based queries are efficient. Ad hoc reporting that needs joins or
  aggregations must be designed as access patterns up front, or computed by the
  History service.
- The data model is harder to change than a relational schema: a new access
  pattern can mean a new item shape or a new index.
- Two storage technologies now exist in the project (PostgreSQL and DynamoDB).
  The team must know both.
- The MiniStack emulator may differ from AWS in details. The `prd` apply is the
  real check.

## Alternatives considered

- **A. A separate PostgreSQL database in the same RDS instance.** Consistent with
  ADR 0005 and simpler to query. Rejected: the history write volume would share the
  instance's CPU, memory and connections with the transactional services, and the
  reporting queries would compete with the write path.
- **B. An append-only log in S3, queried with Athena.** Cheap for storage and good
  for batch analytics. Rejected: the History service needs low-latency queries
  for the reporting endpoints, not only batch analysis.
- **C. Amazon Timestream.** A time-series store with good range queries. Rejected for
  this scope: it is a less common service for the team and the access pattern is
  not time-series-specific.

## Notes

- If the History service needs a second access pattern, the first step is a new
  item shape with a different `PK`/`SK` pattern. A Global Secondary Index is the
  next step. Both are changes to the History service and to this table definition,
  not a change of this decision.
- Table keys and the item model are in the contracts only as far as `resources.md`
  defines the table. Items are defined by the History service.
