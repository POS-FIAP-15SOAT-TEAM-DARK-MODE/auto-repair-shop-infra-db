# ADR 0003 — PostgreSQL as the database engine

- Status: Accepted
- Date: 2026-08-22
- Deciders: Giusier F.
- Tags: database, rds, data-model

## Context

Choice of relational database engine was open — the app's data model (users/roles, customers, vehicles, service orders and their line items, stock, status history) doesn't itself demand one engine over another, so this needed a deliberate call rather than a default.

The workload shape that matters most: several actors (attendant, mechanic, customer) update the same service order and its related stock concurrently; `supply.stock_quantity` gets decremented under contention; lookups are dominated by exact-match filters (`customer.cpf`/`customer.cnpj`, `vehicle.license_plate`, `service_order.status`); and there's a recurring analytical query (average execution time per work item, grouped by status transition) that benefits from real SQL rather than being computed application-side.

## Decision

**PostgreSQL** (RDS PostgreSQL 15, provisioned in `terraform/rds.tf`), for six reasons:

1. **ACID with strong isolation via MVCC** — concurrent updates to the same service order or stock row get a consistent snapshot without the heavier locking a weaker isolation model would need.
2. **Rich indexing** — partial, GIN, GiST and expression indexes fit the actual query shapes here directly.
3. **Concurrent-write performance** — MVCC avoids the write contention that status transitions and stock decrements would otherwise hit.
4. **Analytical queries built in** — window functions and CTEs support the average-execution-time report in SQL, no separate analytics store needed.
5. **Data integrity at the schema level** — `CHECK` constraints (e.g. the `customer` type/document consistency check) and foreign keys enforce business rules the application would otherwise have to re-validate itself.
6. **Managed-service maturity** — RDS PostgreSQL gives multi-AZ failover, automated backups and point-in-time recovery with no operational overhead beyond what's already configured here.

## Consequences

### Positive

- Business-rule enforcement (document consistency, referential integrity) lives partly in the schema, not only in application code.
- The reporting endpoint (`GET /v1/reports/average-execution-time`) is a plain SQL query, not a separate computation path.
- Multi-AZ + automated backups come from the managed service, not custom operational tooling.

### Negative

- PostgreSQL's operational surface (extensions, tuning knobs, replication modes) is broader than a simpler engine would have — unused surface area for a schema this size today, though not a real cost while everything runs through Terraform-managed RDS defaults.
- Ties the schema to Postgres-specific features (partial/GIN/GiST indexes) that would need rework if the engine ever changed.

## Alternatives considered

- **A. MySQL.** Simpler operationally in some respects, but weaker support for indexable JSONB-style variable data and less capable window-function/CTE support for the reporting query. Rejected — no advantage for this workload that offsets those gaps.
- **B. SQL Server.** Viable, but licensing cost and less natural fit with the rest of the AWS-native stack (RDS PostgreSQL is the more common pairing with the Go/Terraform toolchain already in use). Rejected on cost/fit grounds, not technical capability.
- **C. A NoSQL document store (e.g. DynamoDB).** Rejected outright — the data model is inherently relational (service orders reference customers, vehicles, and multiple line-item tables with real referential integrity requirements); modeling that in a document store would mean reimplementing joins and constraints in application code that the relational engine already gives for free.

## Notes

- The current entity-relationship model and the reasoning behind specific modeling choices (snapshot pricing on line items, two separate status-history tables, cascade deletes) are documented in [`docs/database-erd.md`](../database-erd.md), generated from the live migration rather than an earlier design draft.
