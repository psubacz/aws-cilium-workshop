################################################################################
# References
################################################################################
# - https://kubernetes-sigs.github.io/aws-load-balancer-controller/

################################################################################
# Locals
################################################################################

locals {
  aws_load_balancer_controller_chart_version = var.aws_load_balancer_controller_chart_version
}

################################################################################
# Variables
################################################################################

variable "use_aws_load_balancer_controller" {
  type        = bool
  description = "Whether to install the AWS Load Balancer Controller."
  default     = true
}

variable "aws_load_balancer_controller_chart_version" {
  type        = string
  default     = "1.12.0" # AppVersion v2.6.0
  description = "The version of the AWS Load-Balancer Controller chart to use."
}

variable "aws_load_balancer_controller_use_dockerhub_image_repo" {
  type        = bool
  default     = false
  description = "Whether or not to override the default ECR-based image repo with the Dockerhub mirror."
}

variable "aws_load_balancer_controller_namespace" {
  type        = string
  default     = "kube-system"
  description = "The namespace to use for the AWS load balancer controller."
}

variable "default_ssl_policy"{
  type        = string
  description = "The name of the default policy to use."
}

################################################################################
# Role
################################################################################

module "load_balancer_controller_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.55.0"

  count = var.use_aws_load_balancer_controller ? 1 : 0

  role_name                              = "${var.cluster_name}-load-balancer-controller"
  attach_load_balancer_controller_policy = true
  assume_role_condition_test             = "StringLike"

  oidc_providers = {
    (var.cluster_name) = {
      provider_arn               = local.eks_oidc_provider_arn
      namespace_service_accounts = ["${var.aws_load_balancer_controller_namespace}:*"]
    }
  }
  tags = {
    Name = "load_balancer_controller_irsa"
  }
}

################################################################################
# Helm release
################################################################################

resource "helm_release" "load_balancer_controller" {
  count = var.use_aws_load_balancer_controller ? 1 : 0
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = local.aws_load_balancer_controller_chart_version


  namespace        = var.aws_load_balancer_controller_namespace
  create_namespace = true
  
  values = [
    templatefile(
      "values/aws-lbc.yaml",
      {
        cluster_name = var.cluster_name,
        irsa_oidc_provider_arn = module.load_balancer_controller_role[0].iam_role_arn
        default_ssl_policy = var.default_ssl_policy
        aws_vpc_id = data.aws_vpc.selected.id
        aws_region = var.region
      }
    )
  ]
  # Wait on eks irsa role and cilium to be installed
  depends_on = [
    module.load_balancer_controller_role,
  ]
}