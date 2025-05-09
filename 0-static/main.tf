
################################################################################
# Data
################################################################################

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

#################################################################################
# local
#################################################################################

locals {
  partition  = data.aws_partition.current.partition
  account_id = data.aws_caller_identity.current.account_id
}

#################################################################################
# S3 Bucket
#################################################################################

module "cluster_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.6.1"

  bucket = var.terraform_state_bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  control_object_ownership              = true
  object_ownership                      = "BucketOwnerEnforced"
  attach_deny_insecure_transport_policy = true

  versioning = {
    enabled = false
  }
}

# #################################################################################
# # KMS Key
# #################################################################################

module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "1.2.1"

  description = "General KMS key for the devops environment"
  key_usage   = "ENCRYPT_DECRYPT"

  # Policy
  enable_default_policy = false
  key_administrators    = ["arn:${local.partition}:iam::${local.account_id}:role/Admins"]
  key_users             = ["arn:${local.partition}:iam::${local.account_id}:role/PowerUsers", "arn:${local.partition}:iam::${local.account_id}:role/Admins"]
  key_service_users     = ["arn:${local.partition}:iam::${local.account_id}:role/PowerUsers", "arn:${local.partition}:iam::${local.account_id}:role/Admins"]

  key_statements = [
    {
      sid = "Aliases"
      actions = [
        "kms:CreateAlias",
        "kms:DeleteAlias",
        "kms:UpdateAlias",
      ]
      resources = ["*"]

      principals = [
        {
          type        = "AWS"
          identifiers = ["arn:${local.partition}:iam::${local.account_id}:role/PowerUsers", "arn:${local.partition}:iam::${local.account_id}:role/Admins"]
        }
      ]
    }
  ]

  # Aliases
  aliases = [var.terraform_state_bucket]
}
