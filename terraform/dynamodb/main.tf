# History & Reporting service: event-history items (see docs/adr/0006).
# Logical name `history`; the service receives the full name through its
# DYNAMODB_TABLE env var, so the physical name is never hard-coded in code.
resource "aws_dynamodb_table" "history" {
  name         = "${local.name}-history"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  point_in_time_recovery {
    enabled = local.is_prod
  }

  deletion_protection_enabled = local.is_prod

  tags = local.tags
}
