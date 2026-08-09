locals {
  # Must resolve the same way as in auto-repair-shop-infra-k8s: the environment
  # comes from the Terraform workspace, "default" maps to stg.
  #   terraform workspace new stg   (or: terraform workspace select stg)
  environment = terraform.workspace == "default" ? "stg" : terraform.workspace

  name = "${var.project}-${local.environment}"

  tags = {
    Project     = var.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }

  # Per-environment sizing. prd is bigger and more resilient.
  env_config = {
    stg = {
      db_instance = "db.t3.micro"
      multi_az    = false
    }
    prd = {
      db_instance = "db.t3.small"
      multi_az    = true
    }
  }

  cfg     = local.env_config[local.environment]
  is_prod = local.environment == "prd"
}
