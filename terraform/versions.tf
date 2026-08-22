terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state; stg/prd live in separate Terraform workspaces, stored under
  # the env:/<workspace>/ prefix of the same bucket/key. `bucket` is a partial
  # config: the workflow passes it via `-backend-config` (derived from account id).
  # Same S3 bucket as auto-repair-shop-infra-k8s (created once by its
  # `bootstrap` state) — different key, so the two states never collide.
  backend "s3" {
    key          = "db/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
}
