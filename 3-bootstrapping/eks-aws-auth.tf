locals {
  parent_nodegroup_role_arns = [for group in data.aws_eks_node_group.selected : group.node_role_arn]
  nodegroup_role_arns        = local.parent_nodegroup_role_arns
}

data "aws_eks_node_groups" "selected" {
  cluster_name = var.cluster_name
}

data "aws_eks_node_group" "selected" {
  for_each = data.aws_eks_node_groups.selected.names

  cluster_name    = var.cluster_name
  node_group_name = each.value
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "~> 20.0"

  manage_aws_auth_configmap = true

  # Add node roles to aws-auth configmap
  aws_auth_roles = concat(
    # Node group roles
    [for role_arn in local.nodegroup_role_arns : {
      rolearn  = role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    }],
    # Karpenter node role
    var.use_karpenter ? [{
      rolearn  = module.karpenter_aws_infrastructure.node_iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    }] : [],
    # Admin roles
    [{
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Admins"
      username = "Admins"
      groups   = ["system:masters"]
    },
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/PowerUsers"
      username = "PowerUsers"
      groups   = ["system:masters"]
    }]
  )
}