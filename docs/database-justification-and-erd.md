# Database choice and entity-relationship model

## Why PostgreSQL

1. **ACID with strong isolation via MVCC** — service orders, stock and roles get updated by multiple actors (attendant, mechanic, customer) concurrently; PostgreSQL's MVCC gives each transaction a consistent snapshot without the heavier locking a weaker isolation model would need.
2. **Rich indexing** — partial, GIN, GiST and expression indexes fit the actual query shapes here: exact-match lookups on `customer.cpf`/`customer.cnpj`, `vehicle.license_plate`, and `service_order.status`.
3. **Concurrent-write performance** — service order status transitions and `supply.stock_quantity` decrements happen frequently and concurrently; PostgreSQL's MVCC avoids the write contention a simpler locking model would hit under that pattern.
4. **Analytical queries built in** — window functions and CTEs support the average-execution-time reporting (`GET /v1/reports/average-execution-time`) directly in SQL, no separate analytics store needed.
5. **Data integrity at the schema level** — `CHECK` constraints (e.g. the `customer` type/document consistency check) and foreign keys enforce business rules the application would otherwise have to re-validate itself.
6. **Managed-service maturity** — RDS PostgreSQL gives multi-AZ failover, automated backups and point-in-time recovery with no operational overhead beyond what's already configured in `terraform/rds.tf`.

## Entity-relationship diagram

Generated from the live schema in `auto-repair-shop`'s
[`migrations/000001_init_schema.up.sql`](https://github.com/POS-FIAP-15SOAT-TEAM-DARK-MODE/auto-repair-shop/blob/develop/migrations/000001_init_schema.up.sql)
— table names, columns and cardinalities below match what's actually
deployed, not an earlier design draft.

```mermaid
erDiagram
    USER {
        varchar id PK
        varchar name
        varchar email UK
        varchar password_hash
        timestamptz created_at
        timestamptz updated_at
    }

    ROLE {
        varchar id PK
        varchar name UK "ADMIN | MECHANIC | ATTENDANT | CUSTOMER"
        timestamptz created_at
    }

    USER_ROLE {
        varchar id PK
        varchar user_id FK
        varchar role_id FK
    }

    CUSTOMER {
        varchar id PK
        varchar user_id FK "unique — 1:1 with USER"
        varchar type "INDIVIDUAL | COMPANY"
        varchar cpf UK "nullable, set when type = INDIVIDUAL"
        varchar cnpj UK "nullable, set when type = COMPANY"
        varchar company_name "nullable, set when type = COMPANY"
        varchar phone
        timestamptz created_at
        timestamptz updated_at
    }

    VEHICLE {
        varchar id PK
        varchar license_plate UK
        varchar brand
        varchar model
        int year
        varchar customer_id FK
        timestamptz created_at
        timestamptz updated_at
    }

    WORK {
        varchar id PK
        varchar name
        text description
        numeric unit_price
        boolean status "active/inactive"
        timestamptz created_at
        timestamptz updated_at
    }

    SUPPLY {
        varchar id PK
        varchar name
        text description
        numeric unit_price
        int stock_quantity
        int version "optimistic locking"
        timestamptz created_at
        timestamptz updated_at
    }

    SERVICE_ORDER {
        varchar id PK
        varchar customer_id FK
        varchar vehicle_id FK
        varchar status "NEW|RECEIVED|IN_DIAGNOSIS|AWAITING_APPROVAL|REJECTED|IN_PROGRESS|COMPLETED|DELIVERED|CANCELLED"
        numeric total_amount
        timestamptz quote_sent_at "nullable"
        timestamptz completed_at "nullable"
        timestamptz delivered_at "nullable"
        timestamptz created_at
        timestamptz updated_at
    }

    SERVICE_ORDER_WORK {
        varchar id PK
        varchar service_order_id FK
        varchar work_id FK
        numeric unit_price "snapshot at association time"
    }

    SERVICE_ORDER_SUPPLY {
        varchar id PK
        varchar service_order_id FK
        varchar supply_id FK
        int quantity
        numeric unit_price "snapshot at association time"
    }

    SERVICE_ORDER_STATUS_HISTORY {
        varchar id PK
        varchar service_order_id FK
        varchar previous_status
        varchar new_status
        timestamptz created_at
    }

    WORK_SERVICE_ORDER_STATUS_HISTORY {
        varchar id PK
        varchar work_id FK
        varchar service_order_id FK
        varchar previous_status
        varchar new_status
        timestamptz created_at
    }

    USER ||--o{ USER_ROLE : "has"
    ROLE ||--o{ USER_ROLE : "assigned to"
    USER ||--o| CUSTOMER : "linked as"
    CUSTOMER ||--o{ VEHICLE : "owns"
    CUSTOMER ||--o{ SERVICE_ORDER : "requests"
    VEHICLE ||--o{ SERVICE_ORDER : "linked to"
    SERVICE_ORDER ||--o{ SERVICE_ORDER_WORK : "contains"
    WORK ||--o{ SERVICE_ORDER_WORK : "included in"
    SERVICE_ORDER ||--o{ SERVICE_ORDER_SUPPLY : "contains"
    SUPPLY ||--o{ SERVICE_ORDER_SUPPLY : "used in"
    SERVICE_ORDER ||--o{ SERVICE_ORDER_STATUS_HISTORY : "records"
    SERVICE_ORDER ||--o{ WORK_SERVICE_ORDER_STATUS_HISTORY : "records per-work progress for"
    WORK ||--o{ WORK_SERVICE_ORDER_STATUS_HISTORY : "tracked in"
```

## Relationship notes

- **`USER` ↔ `CUSTOMER` is 1:1, not 1:1-optional-both-ways.** Every `CUSTOMER` requires a `USER` (`user_id NOT NULL UNIQUE`), but not every `USER` is a customer — staff accounts (`ADMIN`, `MECHANIC`, `ATTENDANT`) are `USER` rows with no matching `CUSTOMER` row. This is also how the `lambda-auth` customer-login function resolves a CPF: `customer.cpf` → `customer.user_id` → roles via `USER_ROLE`.
- **`USER` ↔ `ROLE` is many-to-many** through `USER_ROLE`, so a single user can hold multiple roles simultaneously (e.g. an `ADMIN` who is also an `ATTENDANT`).
- **`WORK` vs. `SUPPLY`** are deliberately separate entities rather than a single "line item" table: `WORK` is a billable service with no stock concept; `SUPPLY` carries `stock_quantity` and an optimistic-locking `version` column, since parts get decremented under concurrent service orders and need conflict detection that a labor line item never does.
- **Two status-history tables, not one.** `SERVICE_ORDER_STATUS_HISTORY` tracks the order's own status transitions; `WORK_SERVICE_ORDER_STATUS_HISTORY` separately tracks each individual work item's progress *within* a service order (e.g. one work item can be `IN_PROGRESS` while another on the same order is already `COMPLETED`). Collapsing these into one table would conflate order-level and work-level state machines that advance independently.
- **`SERVICE_ORDER_WORK` and `SERVICE_ORDER_SUPPLY` both snapshot `unit_price`** at the time the work/supply is added to the order, rather than joining live to `WORK.unit_price`/`SUPPLY.unit_price`. A later price change on the catalog item must not retroactively alter the total on an already-quoted or already-approved order.
- **Cascading deletes are deliberate, not incidental.** `ON DELETE CASCADE` runs from `USER` down through `CUSTOMER`, `VEHICLE` and `USER_ROLE`, and from `SERVICE_ORDER` down through its line items and status history — removing a customer's user account or a service order is expected to take its dependent rows with it, rather than leaving orphaned records.
