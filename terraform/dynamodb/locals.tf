locals {
  # Same rule as terraform/locals.tf: the environment comes from the Terraform
  # workspace, "default" maps to stg.
  environment = terraform.workspace == "default" ? "stg" : terraform.workspace

  name = "${var.project}-${local.environment}"

  tags = {
    Project     = var.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }

  is_prod = local.environment == "prd"
}
