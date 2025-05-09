################################################################################
# Providers
################################################################################

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
  backend "s3" {
    bucket  = "cilium-test"
    key     = "terraform/us-east-2/vpc/terraform.tfstate"
    region  = "us-east-2"
    profile = "aether-sandbox-gov"
    encrypt = true
  }
}