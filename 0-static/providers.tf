terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    dns = {
      source  = "hashicorp/dns"
      version = ">= 3.2.3"
    }
  }
  required_version = ">= 0.14.9"
}

################################################################################
# Providers
################################################################################

provider "aws" {
  profile = var.profile
  region  = var.region

  default_tags {
    tags = var.default_tags
  }
}
