################################################################################
# Data
################################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

# The maxar-cidr-blocks module acts as a data source
module "maxar_ips" {
  source = "gitlab.iap.maxar.com/devops/maxar-cidr-blocks/null"
}

################################################################################
# Locals
################################################################################

locals {
  number_of_azs = length(data.aws_availability_zones.available.names)
  subnet_cidrs = cidrsubnets(var.vpc_cidr, concat(
    [for i in data.aws_availability_zones.available.names : 3],
    [for i in data.aws_availability_zones.available.names : 6])...
  )
  private_subnet_cidrs = chunklist(local.subnet_cidrs, local.number_of_azs)[0]
  public_subnet_cidrs  = chunklist(local.subnet_cidrs, local.number_of_azs)[1]
}

################################################################################
# VPC
################################################################################
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  # version = "5.1.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.available.names
  private_subnets = local.private_subnet_cidrs
  public_subnets  = local.public_subnet_cidrs

  enable_nat_gateway            = true
  single_nat_gateway            = true
  one_nat_gateway_per_az        = false
  enable_dns_support            = true
  enable_dns_hostnames          = true
  map_public_ip_on_launch       = false
  manage_default_security_group = true

  enable_flow_log           = var.vpc_flow_log_bucket_arn != null
  flow_log_destination_type = var.vpc_flow_log_bucket_arn != null ? "s3" : null
  flow_log_destination_arn  = var.vpc_flow_log_bucket_arn

  public_subnet_tags = {
    "kubernetes.io/role/elb" : "1"
    Tier = "Public"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" : "1"
    Tier                     = "Private"
    "karpenter.sh/discovery" = var.vpc_name
  }

  public_acl_tags = {
    Public = "true"
  }
}
