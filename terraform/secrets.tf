# Per-service database credentials in Secrets Manager (fase 4).
#
# Each service gets its own database and login role on the shared RDS
# instance (created by db-bootstrap/). The JSON keys of every secret are the
# environment variable names the service reads. The legacy secret
# `${local.name}/app` (rds.tf) is kept untouched until the monolith is retired.

locals {
  # key -> database and login role names. `internal` = the service exposes
  # /internal/* or calls services that do, so it also gets INTERNAL_TOKEN.
  # Secret names use "-" instead of "_" (service_order -> service-order).
  pg_services = {
    customer      = { db = "customer", user = "customer_app", internal = true }
    catalog       = { db = "catalog", user = "catalog_app", internal = true }
    billing       = { db = "billing", user = "billing_app", internal = false }
    execution     = { db = "execution", user = "execution_app", internal = false }
    service_order = { db = "service_order", user = "service_order_app", internal = true }
  }
}

resource "random_password" "service_db" {
  for_each = local.pg_services

  length  = 24
  special = false
}

# One INTERNAL_TOKEN per environment, shared by the services that use it.
resource "random_password" "internal_token" {
  length  = 40
  special = false
}

# Password of the read-only login role used by the customer-login lambda.
resource "random_password" "lambda_ro" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "service" {
  for_each = local.pg_services

  name = "${local.name}/${replace(each.key, "_", "-")}"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "service" {
  for_each = local.pg_services

  secret_id = aws_secretsmanager_secret.service[each.key].id
  secret_string = jsonencode(merge(
    {
      POSTGRES_USER     = each.value.user
      POSTGRES_PASSWORD = random_password.service_db[each.key].result
      POSTGRES_DB       = each.value.db
      JWT_SECRET        = random_password.jwt.result
    },
    each.value.internal ? { INTERNAL_TOKEN = random_password.internal_token.result } : {},
  ))
}

resource "aws_secretsmanager_secret" "history" {
  name = "${local.name}/history"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "history" {
  secret_id = aws_secretsmanager_secret.history.id
  secret_string = jsonencode({
    JWT_SECRET = random_password.jwt.result
  })
}

# Same keys the customer-login lambda already reads (POSTGRES_PASSWORD, JWT_SECRET).
resource "aws_secretsmanager_secret" "lambda_auth" {
  name = "${local.name}/lambda-auth"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "lambda_auth" {
  secret_id = aws_secretsmanager_secret.lambda_auth.id
  secret_string = jsonencode({
    POSTGRES_PASSWORD = random_password.lambda_ro.result
    JWT_SECRET        = random_password.jwt.result
  })
}
