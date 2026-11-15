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

output "pg_services" {
  description = "Per-service database and login role (key = service name as in the secret suffix). Read by the infra workflow to bootstrap the databases."
  value = {
    for k, s in local.pg_services : replace(k, "_", "-") => { db = s.db, user = s.user }
  }
}

output "service_secret_arns" {
  description = "Per-service Secrets Manager ARNs (key = secret suffix: customer, catalog, billing, execution, service-order)"
  value = {
    for k, s in aws_secretsmanager_secret.service : replace(k, "_", "-") => s.arn
  }
}

output "lambda_secret_arn" {
  description = "Secrets Manager secret for the customer-login lambda (POSTGRES_PASSWORD of lambda_auth_ro, JWT_SECRET). Replaces app_secret_arn for the lambda in F9."
  value       = aws_secretsmanager_secret.lambda_auth.arn
}

output "cloudwatch_dashboard_url" {
  description = "Console link to the RDS CPU/memory/connections dashboard"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.rds.dashboard_name}"
}

output "lambda_access_security_group_id" {
  description = "Consumed by auto-repair-shop-lambda-auth: attach the customer-login lambda's VPC config to this SG to get RDS ingress on 5432."
  value       = aws_security_group.lambda_access.id
}
