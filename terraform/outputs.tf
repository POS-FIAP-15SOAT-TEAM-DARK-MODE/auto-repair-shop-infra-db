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

output "cloudwatch_dashboard_url" {
  description = "Console link to the RDS CPU/memory/connections dashboard"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.rds.dashboard_name}"
}
