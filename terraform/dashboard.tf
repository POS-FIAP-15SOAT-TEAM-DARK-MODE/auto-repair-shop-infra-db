# CloudWatch dashboard for the RDS instance's own infra metrics — no agent to
# install, RDS already publishes these to CloudWatch on its own.
resource "aws_cloudwatch_dashboard" "rds" {
  dashboard_name = "${local.name}-rds"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "CPU Utilization (%)"
          region = var.region
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", module.rds.db_instance_identifier],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Freeable Memory (bytes)"
          region = var.region
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", module.rds.db_instance_identifier],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Database Connections"
          region = var.region
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", module.rds.db_instance_identifier],
          ]
        }
      },
    ]
  })
}
