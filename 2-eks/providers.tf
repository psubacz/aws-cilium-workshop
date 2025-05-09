terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # version = "5.29.0"
    }
    tls = {
      source = "hashicorp/tls"
      # version = "4.0.5"
    }
  }
  required_version = ">= 0.14.9"

  backend "s3" {
    bucket  = "cilium-test"
    key     = "terraform/us-east-2/eks/terraform.tfstate"
    region  = "us-east-2"
    profile = "aether-sandbox-gov"
    encrypt = true
  }
}

################################################################################
# Providers
################################################################################

provider "aws" {
  profile = var.profile # Must match the profile name in your ~/.okta_aws_login_config file
  region  = var.region

  default_tags {
    tags = var.default_tags
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# provider "aws" {
#   # Must match the profile name in your ~/.okta_aws_login_config file
#   region  = "us-east-2"
#   profile = "aether-sandbox-gov"
#   alias   = "commercial"

#   default_tags {
#     tags = var.default_tags
#   }
# }

# provider "aws" {
#   # Must match the profile name in your ~/.okta_aws_login_config file
#   profile = "aether-sandbox"
#   region  = "us-east-1"
#   alias   = "sandbox"

#   default_tags {
#     tags = merge(
#       {
#         AWS_Nuke_Ignore = "True"
#       },
#       var.default_tags
#     )
#   }
# }