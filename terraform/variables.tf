variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name, used as a resource prefix. Must match the project name used by auto-repair-shop-infra-k8s so both repos derive the same environment name/tags."
  type        = string
  default     = "auto-repair-shop"
}

variable "state_bucket" {
  description = "S3 bucket holding the remote state — the same bucket created by auto-repair-shop-infra-k8s's bootstrap state. Passed by the workflow, derived from the AWS account id."
  type        = string
}

# --- RDS (Postgres) ---
# Per-environment sizing (instance class, multi-AZ) is derived from the
# workspace in locals.tf; these are the values common to all environments.
variable "db_name" {
  type    = string
  default = "autorepairshop"
}

variable "db_username" {
  type    = string
  default = "postgres"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_engine_version" {
  type    = string
  default = "15"
}
