################################################################################
# Data
################################################################################

data "aws_default_tags" "current" {}

# The maxar-cidr-blocks module acts as a data source
module "maxar_ips" {
  source = "gitlab.iap.maxar.com/devops/maxar-cidr-blocks/null"
}

data "aws_vpc" "selected" {
  tags = {
    Name = var.cluster_name
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

data "aws_nat_gateways" "ngws" {
  vpc_id = local.vpc_id

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_nat_gateway" "ngw" {
  count = length(data.aws_nat_gateways.ngws.ids)

  id = tolist(data.aws_nat_gateways.ngws.ids)[count.index]
}

################################################################################
# local
################################################################################

locals {
  vpc_id          = data.aws_vpc.selected.id
  private_subnets = data.aws_subnets.private.ids
  nat_public_ips  = [for ngw in data.aws_nat_gateway.ngw : ngw.public_ip]
  allowed_cidrs = concat(
    module.maxar_ips.public_cidrs,
    [for ip in local.nat_public_ips : "${ip}/32"],
    var.additional_allowed_cidrs,
  )
}
