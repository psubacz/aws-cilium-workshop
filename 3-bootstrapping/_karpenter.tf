################################################################################
# References
################################################################################
# - https://github.com/kubernetes-sigs/karpenter?tab=readme-ov-file
# - https://karpenter.sh/
# - https://github.com/aws/karpenter-provider-aws/blob/main/charts/karpenter/values.yaml


################################################################################
# Locals
################################################################################
locals {
  cluster_name = var.cluster_name
  karpenter_chart_version = "1.4.0"
}

# ################################################################################
# # Variables
# ################################################################################
variable "use_karpenter" {
  type        = bool
  default     = true
  description = "Whether to install use_karpenter."
}

# ################################################################################
# # K8S Installations
# ################################################################################

### Setup backend permissions 
module "karpenter_aws_infrastructure" {
  count = var.use_karpenter ? 1 : 0
  source = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.36.0"

  cluster_name = var.cluster_name
  create_instance_profile = true

  # IRSA configuration for the Karpenter controller
  create_iam_role = true
  enable_irsa = true
  enable_v1_permissions = true
  irsa_oidc_provider_arn = local.eks_oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]

  # Attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    # Add EC2 permissions needed by Karpenter
    AmazonEC2FullAccess = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
    "karpenter.sh/discovery" = var.cluster_name
  }
}

resource "time_sleep" "karpenter_wait" {
  count = var.use_karpenter ? 1 : 0

  destroy_duration = "30s"
  create_duration  = "30s"

  triggers = {
    karpenter = module.karpenter_aws_infrastructure.node_iam_role_arn
    controller = module.karpenter_aws_infrastructure.iam_role_arn
  }

  depends_on = [
    module.karpenter_aws_infrastructure
  ]
}

## CRDs are coupled to the version of Karpenter, and should be updated along with Karpenter.
resource "helm_release" "karpenter_crd" {
  count = var.use_karpenter ? 1 : 0

  name       = "karpenter-crd"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter-crd"
  version    = local.karpenter_chart_version

  upgrade_install = true
  reuse_values = true

  # No need for values template for CRD chart
  values = []
}

resource "helm_release" "karpenter" {
  count = var.use_karpenter ? 1 : 0
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = local.karpenter_chart_version

  namespace = "karpenter"
  create_namespace = true
  
  values = [
    templatefile(
      "values/karpenter.yaml",
      {
        cluster_name = local.cluster_name,
        interruption_queue = module.karpenter_aws_infrastructure.queue_name
        controller_iam_role_arn = module.karpenter_aws_infrastructure.iam_role_arn
        account_id = data.aws_caller_identity.current.account_id
      }
    )
  ]
  
  depends_on = [
    helm_release.karpenter_crd,
    module.karpenter_aws_infrastructure,
    time_sleep.karpenter_wait
  ]
}




################################################################################
# Karpenter Configs - Using Template Files
################################################################################

resource "kubectl_manifest" "karpenter_ec2_node_class" {
  count = var.use_karpenter ? 1 : 0
  yaml_body = templatefile(
    "${path.module}/karpenter-manifests/ec2nodeclass.yaml.tftpl",
    {
      node_iam_role_name = module.karpenter_aws_infrastructure.node_iam_role_name
      cluster_name = var.cluster_name
    }
  )

  depends_on = [
    time_sleep.karpenter_wait,
    helm_release.karpenter
  ]
}

# With Cilium config
resource "kubectl_manifest" "karpenter_node_pool" {
  count = var.use_karpenter && var.use_cilium ? 1 : 0
  yaml_body = templatefile(
    "${path.module}/karpenter-manifests/nodepool.yaml.tftpl",
    {
      availability_zones = jsonencode(local.availability_zones)
    }
  )
  
  depends_on = [
    kubectl_manifest.karpenter_ec2_node_class,
    helm_release.karpenter
  ]
}

# Add a non-Cilium NodePool if needed
resource "kubectl_manifest" "karpenter_node_pool_no_cilium" {
  count = var.use_karpenter && !var.use_cilium ? 1 : 0
  yaml_body = templatefile(
    "${path.module}/karpenter-manifests/nodepool-no-cilium.yaml.tftpl",
    {
      availability_zones = jsonencode(local.availability_zones)
    }
  )
  
  depends_on = [
    kubectl_manifest.karpenter_ec2_node_class,
    helm_release.karpenter
  ]
}