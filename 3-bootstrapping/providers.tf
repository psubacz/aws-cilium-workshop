################################################################################
# Providers
################################################################################

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      # version = ">= 2.8.0"
    }
    aws = {
      source  = "hashicorp/aws"
      # version = ">= 3.27"
    }
    kubectl = {
      source  = "alekc/kubectl"
      # version = "2.0.2"
    }
    random = {
      source  = "hashicorp/random"
      # version = "3.5.1"
    }
    tls = {
      source  = "hashicorp/tls"
      # version = "4.0.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.12.1"
    }
  }
  required_version = ">= 0.14.9"
    backend "s3" {
    bucket  = "cilium-test"
    key     = "terraform/us-east-2/bootstrap/terraform.tfstate"
    region  = "us-east-2"
    profile = "aether-sandbox-gov"
    encrypt = true
  }
}

provider "aws" {
  profile = var.profile # Must match the profile name in your ~/.okta_aws_login_config file
  region  = var.region

  default_tags {
    tags = var.default_tags
  }
}

provider "helm" {
  kubernetes {
    host                   = local.eks_cluster.endpoint
    cluster_ca_certificate = base64decode(local.eks_cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.selected.token
  }

  # experiments {
  #   manifest = true
  # }
}

provider "kubernetes" {
  host                   = local.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(local.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.selected.token
}

provider "kubectl" {
  host                   = local.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(local.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.selected.token
}