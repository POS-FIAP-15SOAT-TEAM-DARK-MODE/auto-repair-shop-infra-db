terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Own state, separate from the RDS one (terraform/) so the two layers can be
  # applied independently. Same bucket as the other states; `bucket` is passed
  # by the workflow via -backend-config.
  backend "s3" {
    key          = "dynamodb/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  # Only for a local run against MiniStack (CI job dynamodb-ministack): no
  # credential validation, no metadata or STS lookups. In AWS these stay off
  # and the normal credential chain is used.
  skip_credentials_validation = var.aws_endpoint != null
  skip_metadata_api_check     = var.aws_endpoint != null
  skip_requesting_account_id  = var.aws_endpoint != null

  dynamic "endpoints" {
    for_each = var.aws_endpoint == null ? [] : [var.aws_endpoint]

    content {
      dynamodb = endpoints.value
    }
  }
}
