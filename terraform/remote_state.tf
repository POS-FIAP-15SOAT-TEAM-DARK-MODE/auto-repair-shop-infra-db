# Network (VPC + EKS node security group) comes from the sibling
# auto-repair-shop-infra-k8s repo's `aws` state — same workspace, same S3
# bucket, different key. This repo never creates or duplicates network
# resources; it only places the RDS instance inside them.
data "terraform_remote_state" "network" {
  backend   = "s3"
  workspace = terraform.workspace

  config = {
    bucket = var.state_bucket
    key    = "aws/terraform.tfstate"
    region = var.region
  }
}
