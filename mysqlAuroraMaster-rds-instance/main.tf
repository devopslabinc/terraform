terraform {
  required_version = ">= 0.11.0"
}

provider "aws" {
  region = "us-east-2"
}

variable "azs" {
  type = "list"

  default = [
    "us-east-2a",
    "us-east-2b",
    "us-east-2c",
  ]
}

module "aurora" {
  source                          = ""
  name                            = "aurora-rds"
  engine                          = "aurora-mysql"
  engine_version                  = "5.7.12"
  subnets                         = ["${module.vpc.database_subnets}"]
  vpc_id                          = "${module.vpc.vpc_id}"
  replica_count                   = 1
  instance_type                   = "db.t2.small"
  key_name                        = "${var.key_name}"
  apply_immediately               = true
  skip_final_snapshot             = true
  db_parameter_group_name         = "${aws_db_parameter_group.aurora_db_57_parameter_group.id}"
  db_cluster_parameter_group_name = "${aws_rds_cluster_parameter_group.aurora_57_cluster_parameter_group.id}"
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
}

resource "aws_db_parameter_group" "aurora_db_57_parameter_group" {
  name        = "test-aurora-db-57-parameter-group"
  family      = "aurora-mysql5.7"
  description = "test-aurora-db-57-parameter-group"
}

resource "aws_rds_cluster_parameter_group" "aurora_57_cluster_parameter_group" {
  name        = "test-aurora-57-cluster-parameter-group"
  family      = "aurora-mysql5.7"
  description = "test-aurora-57-cluster-parameter-group"
}

resource "aws_security_group" "app_servers" {
  name        = "app-servers"
  description = "For application servers"
  vpc_id      = "${module.vpc.vpc_id}"
}

resource "aws_security_group_rule" "allow_access" {
  type                     = "ingress"
  from_port                = "${module.aurora.this_rds_cluster_port}"
  to_port                  = "${module.aurora.this_rds_cluster_port}"
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.app_servers.id}"
  security_group_id        = "${module.aurora.this_security_group_id}"
}

module "vpc" {
  source = ""
  name   = "example"
  cidr   = "10.0.0.0/16"
  azs    = ["${var.azs}"]

  private_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/25",
  ]

  public_subnets = [
    "10.0.4.0/24",
    "10.0.5.0/24",
    "10.0.6.0/25",
  ]

  database_subnets = [
    "10.0.7.0/24",
    "10.0.8.0/24",
    "10.0.9.0/25",
  ]
}

# IAM Policy for use with iam_database_authentication = true
resource "aws_iam_policy" "aurora_mysql_policy_iam_auth" {
  name = "test-aurora-db-57-policy-iam-auth"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds-db:connect"
      ],
      "Resource": [
        "arn:aws:rds-db:us-east-1:123456789012:dbuser:${module.aurora.this_rds_cluster_resource_id}/jane_doe"
      ]
    }
  ]
}
POLICY
}