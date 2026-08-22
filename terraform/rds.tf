# Managed Postgres for the app in AWS. Locally (Kind) this is replaced by an
# in-cluster Postgres in the app repo's local kustomize overlay.
resource "random_password" "db" {
  length  = 24
  special = false
}

# JWT signing secret, generated per environment. Lives here (not in
# auto-repair-shop-infra-k8s) because it is generated together with the DB
# password and mirrored into the same Secrets Manager entry below.
resource "random_password" "jwt" {
  length  = 48
  special = false
}

resource "aws_security_group" "rds" {
  name_prefix = "${local.name}-rds-"
  description = "Allow Postgres only from the EKS node group"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    description     = "Postgres from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.network.outputs.node_security_group_id]
  }

  ingress {
    description     = "Postgres from the customer-login lambda (auto-repair-shop-lambda-auth)"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_access.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${local.name}-db"

  engine               = "postgres"
  engine_version       = var.db_engine_version
  family               = "postgres15"
  major_engine_version = var.db_engine_version
  instance_class       = local.cfg.db_instance
  allocated_storage    = var.db_allocated_storage

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 5432

  # We manage the password ourselves and mirror it into Secrets Manager (below)
  # so External Secrets can sync it into the cluster.
  manage_master_user_password = false

  multi_az                = local.cfg.multi_az
  subnet_ids              = data.terraform_remote_state.network.outputs.private_subnets
  create_db_subnet_group  = true
  vpc_security_group_ids  = [aws_security_group.rds.id]

  skip_final_snapshot = !local.is_prod
  deletion_protection = local.is_prod

  tags = local.tags
}

# Workload secrets in Secrets Manager. The External Secrets Operator installed
# by auto-repair-shop-infra-k8s's `addons` state syncs this into the app's
# Kubernetes Secret — same name pattern (`${local.name}/app`) on both sides.
resource "aws_secretsmanager_secret" "app" {
  name = "${local.name}/app"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    POSTGRES_PASSWORD = random_password.db.result
    JWT_SECRET        = random_password.jwt.result
  })
}
