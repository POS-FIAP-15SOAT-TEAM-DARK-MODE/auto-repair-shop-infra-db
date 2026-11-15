output "environment" {
  value = local.environment
}

output "history_table_name" {
  description = "Value for the history service's DYNAMODB_TABLE env var"
  value       = aws_dynamodb_table.history.name
}

output "history_table_arn" {
  value = aws_dynamodb_table.history.arn
}
