variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name, used as a resource prefix. Must match the other infra states."
  type        = string
  default     = "auto-repair-shop"
}

variable "aws_endpoint" {
  description = "Endpoint override for a local MiniStack run (e.g. http://localhost:4566). Leave unset in AWS."
  type        = string
  default     = null
}

variable "state_bucket" {
  description = "Not used by this state (no remote_state dependency). Accepted only so the workflow can pass the same -var to every layer."
  type        = string
  default     = null
}
