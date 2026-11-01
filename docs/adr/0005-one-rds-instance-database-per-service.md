# ADR 0005 — One RDS instance, one database and login role per service

- Status: Accepted
- Date: 2026-11-01
- Deciders: Auto Repair Shop Team
- Tags: database, rds, microservices, security, cost

## Context

The monolith keeps every table in one PostgreSQL database (`autorepairshop`) with
one application user. The split into services (fase 4) needs each service to own
its data: a service must not read or write another service's tables, and the
schema of one service must be able to change without touching the others.

The environment is the AWS Academy Learner Lab (`manage_iam=false`, static
credentials). It has a limited budget and few resources, and this repository
already owns a working RDS instance (`auto-repair-shop-<env>/app` secret, EKS
security-group ingress, lambda ingress).

## Decision

Keep the single RDS instance and create one **database** and one **login role**
per service inside it:

| Service | Database | Role |
|---|---|---|
| Customer & Identity | `customer` | `customer_app` |
| Catalog | `catalog` | `catalog_app` |
| Billing | `billing` | `billing_app` |
| Execution | `execution` | `execution_app` |
| Service Order | `service_order` | `service_order_app` |

- Each database is owned by its role. `REVOKE CONNECT … FROM PUBLIC` is applied to
  each one, so a role connects only to its own database.
- The customer-login lambda gets a separate read-only role (`lambda_auth_ro`) with
  `CONNECT` and `SELECT` on the `customer` database only.
- The databases and roles are created by an idempotent Job (`db-bootstrap/`) that
  runs after the RDS layer is applied. Each role's password is kept in its own
  Secrets Manager secret (`auto-repair-shop-<env>/<service>`).
- No foreign keys cross databases. Cross-service references are logical IDs that
  services check through their APIs or messages.
- The legacy secret `auto-repair-shop-<env>/app` and the monolith's database stay
  until the gateway replaces the monolith (F10).

## Consequences

### Positive

- Data ownership is explicit: each service has its own schema, roles and
  credentials, and can migrate them independently.
- One instance keeps the cost and the Learner Lab resource footprint of the
  current setup. There is no extra RDS instance per service to provision or patch.
- Access is least-privilege at the database level, not only in the application.
- The bootstrap is idempotent, so it can run on every deploy and re-syncs the
  passwords with Secrets Manager.

### Negative

- The instance is still a shared failure domain: a crash, a bad migration on the
  instance or a maintenance window affects all services at once. Multi-AZ in `prd`
  reduces but does not remove this.
- Every service shares the instance's CPU, memory and connection limit. Connection
  usage is watched through the CloudWatch dashboard (ADR 0004).
- The bootstrap runs with the master user. Its password stays in the
  `auto-repair-shop-<env>/app` secret until F10.

## Alternatives considered

- **A. One RDS instance per service.** Strongest isolation and independent scaling.
  Rejected for now: it multiplies cost and provisioning time, and does not fit the
  Learner Lab budget. It stays possible later, because each database is already
  separate and has its own credentials.
- **B. One database with one schema per service.** Cheaper than A, but a single
  database owner and shared `search_path` make the isolation weaker. Rejected in
  favour of separate databases, which give a clear `CONNECT` boundary.
- **C. One shared schema for all services.** Rejected: it is the coupling the split
  is meant to remove.

## Notes

- The DDL of each database is the contract in `docs/fase4/contracts/ddl.md` of the
  umbrella repository. The per-database models are in
  [`docs/database-erd.md`](../database-erd.md).
- The role and database names are fixed in `docs/fase4/contracts/resources.md`.
  Changing one means changing it in every service and in `db-bootstrap/`.
