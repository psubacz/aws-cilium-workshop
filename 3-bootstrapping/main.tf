################################################################################
# Data
################################################################################

# data "aws_region" "current" {}
# data "aws_default_tags" "current" {}
data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "selected" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "selected" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "selected" {
  url = data.aws_eks_cluster.selected.identity[0].oidc[0].issuer
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_vpc" "selected" {
  tags = {
    Name = var.cluster_name
  }
}

################################################################################
# local
################################################################################

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  # availability_zones = {
  #   availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  #   aws        = ["us-east-1a", "us-east-1b"]
  #   aws-us-gov = ["us-gov-east-1a", "us-gov-east-1b"]
  # }[data.aws_partition.current.partition]

  # default_tags          = data.aws_default_tags.current.tags
  eks_cluster           = data.aws_eks_cluster.selected
  eks_api_endpoint      = trimprefix(data.aws_eks_cluster.selected.endpoint, "https://")
  eks_api_port          = 443
  eks_oidc_provider_arn = data.aws_iam_openid_connect_provider.selected.arn
}
