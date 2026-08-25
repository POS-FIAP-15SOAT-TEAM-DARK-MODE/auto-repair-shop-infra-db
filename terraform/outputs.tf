output "environment" {
  value = local.environment
}

output "db_host" {
  description = "RDS endpoint; set as POSTGRES_HOST / RDS_HOST in the app repo's env overlay and GitHub Environment variable"
  value       = module.rds.db_instance_address
}

output "db_port" {
  value = module.rds.db_instance_port
}

output "app_secret_arn" {
  description = "Secrets Manager secret with POSTGRES_PASSWORD/JWT_SECRET (synced into the cluster by External Secrets, installed in auto-repair-shop-infra-k8s)"
  value       = aws_secretsmanager_secret.app.arn
}

output "lambda_access_security_group_id" {
  description = "Consumed by auto-repair-shop-lambda-auth: attach the customer-login lambda's VPC config to this SG to get RDS ingress on 5432."
  value       = aws_security_group.lambda_access.id
}
