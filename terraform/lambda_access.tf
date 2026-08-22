# Dedicated security group for auto-repair-shop-lambda-auth to attach its
# Lambda function to, so it can reach RDS. Owned here (not created in the
# lambda repo) specifically to avoid a circular cross-repo dependency: this
# repo already needs to be applied before the lambda repo (it reads db_host
# and app_secret_arn from here), so if the lambda repo owned this SG, this
# repo's RDS ingress rule would need the lambda repo applied FIRST — a cycle.
# Owning the (empty, egress-only) SG here breaks that: the lambda repo just
# attaches its function to this pre-existing SG via terraform_remote_state.
resource "aws_security_group" "lambda_access" {
  name_prefix = "${local.name}-lambda-access-"
  description = "Attached by auto-repair-shop-lambda-auth's function; grants it RDS ingress below. No rules of its own - pure identity group."
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}
