#!/bin/sh
# Idempotent bootstrap of the per-service databases and login roles on the
# shared RDS instance. Runs as the `db-bootstrap` Kubernetes Job
# (db-bootstrap/job.yaml) with the master user. Safe to run any number of
# times: every object is created only if missing, and passwords are re-synced
# with the Secrets Manager values on each run.
#
# Required env: PGHOST, PGUSER, PGPASSWORD (master), PW_CUSTOMER, PW_CATALOG,
# PW_BILLING, PW_EXECUTION, PW_SERVICE_ORDER, PW_LAMBDA.
# Optional env: PGPORT (default 5432), PGSSLMODE (default require).
# Passwords are passed to psql as variables and never printed.
set -eu

: "${PGHOST:?PGHOST is required}"
: "${PGUSER:?PGUSER is required}"
: "${PGPASSWORD:?PGPASSWORD is required}"
: "${PW_CUSTOMER:?PW_CUSTOMER is required}"
: "${PW_CATALOG:?PW_CATALOG is required}"
: "${PW_BILLING:?PW_BILLING is required}"
: "${PW_EXECUTION:?PW_EXECUTION is required}"
: "${PW_SERVICE_ORDER:?PW_SERVICE_ORDER is required}"
: "${PW_LAMBDA:?PW_LAMBDA is required}"
export PGSSLMODE="${PGSSLMODE:-require}"

# All admin work runs against the `postgres` maintenance database. ON_ERROR_STOP
# makes the first failing statement fail the whole script.
admin_sql() {
  psql -X -q -v ON_ERROR_STOP=1 -d postgres "$@"
}

# provision_service <login role> <database> <password>
# The role is the database owner, so the master user must be a member of it
# first (required on RDS to set OWNER). \gexec runs the generated statement
# only when the guard query returns a row, which keeps re-runs no-ops.
provision_service() {
  local role="$1"
  local db="$2"
  local pw="$3"
  admin_sql -v role="$role" -v db="$db" -v pw="$pw" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN', :'role')
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'role') \gexec
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'role', :'pw') \gexec
SELECT format('GRANT %I TO CURRENT_USER', :'role') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db', :'role')
 WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db') \gexec
REVOKE ALL ON DATABASE :"db" FROM PUBLIC;
SQL
}

# provision_lambda_role <password>: read-only login role for the customer-login lambda.
provision_lambda_role() {
  local pw="$1"
  admin_sql -v role="lambda_auth_ro" -v pw="$pw" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN', :'role')
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'role') \gexec
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'role', :'pw') \gexec
SQL
}

# grant_lambda_read: lets lambda_auth_ro read the customer database.
# Runs inside `customer` as customer_app (the database owner), because on
# PostgreSQL 15+ schema public belongs to the database owner. The
# ALTER DEFAULT PRIVILEGES covers tables created later by the customer
# migrations; the explicit GRANT covers tables that already exist on re-runs.
grant_lambda_read() {
  psql -X -q -v ON_ERROR_STOP=1 -d customer -v ro="lambda_auth_ro" <<'SQL'
SET ROLE customer_app;
GRANT CONNECT ON DATABASE customer TO :"ro";
GRANT USAGE ON SCHEMA public TO :"ro";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO :"ro";
ALTER DEFAULT PRIVILEGES FOR ROLE customer_app IN SCHEMA public GRANT SELECT ON TABLES TO :"ro";
SQL
}

provision_service customer_app customer "$PW_CUSTOMER"
provision_service catalog_app catalog "$PW_CATALOG"
provision_service billing_app billing "$PW_BILLING"
provision_service execution_app execution "$PW_EXECUTION"
provision_service service_order_app service_order "$PW_SERVICE_ORDER"

provision_lambda_role "$PW_LAMBDA"
grant_lambda_read

echo "db-bootstrap: roles"
admin_sql -c '\du'
echo "db-bootstrap: databases"
admin_sql -c '\l'
echo "db-bootstrap: done"
