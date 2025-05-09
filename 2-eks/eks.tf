
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name                    = var.cluster_name
  cluster_version                 = var.kubernetes_version
  cluster_enabled_log_types       = ["audit", "api", "authenticator", "controllerManager", "scheduler"]
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access

  cluster_endpoint_public_access_cidrs = local.allowed_cidrs

  vpc_id     = local.vpc_id
  subnet_ids = slice(local.private_subnets, 0, 2)

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  # Tells eks to add addons before nodes created 
  bootstrap_self_managed_addons = true
  cluster_addons = {
    vpc-cni = {}
    kube-proxy = {}
    coredns = {
      configuration_values = jsonencode({
        tolerations = [
          {
            key   = "CriticalAddonsOnly"
            value = "true"
            effect = "NoSchedule"
          },
        ]
        nodeSelector = {
          "dedicated" = "bootstrap"
        }
      })
    }

    #   # Disabling the AWS VPC CNI as we'll use Cilium instead
    #   vpc-cni                = {
    #     most_recent = true
    #     before_compute = true
    #     configuration_values = jsonencode({
    #       env = {
    #         # Disable WARM_ENI_TARGET and WARM_IP_TARGET to prevent IP allocation
    #         WARM_ENI_TARGET = "0"
    #         WARM_IP_TARGET = "0"
    #         # These settings are required for "zero" mode to disable the CNI's IPAM
    #         AWS_VPC_K8S_CNI_EXTERNALSNAT = "true"
    #         DISABLE_NETWORK_RESOURCE_PROVISIONING = "true"
    #       }
    #     })
    #   }
  }

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    vpc_security_group_ids = []
    subnet_ids             = local.private_subnets
    launch_template_tags   = data.aws_default_tags.current.tags

    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 50
          volume_type           = "gp3"
          encrypted             = false
          delete_on_termination = true
        }
      }
    }
  }

  eks_managed_node_groups = var.eks_managed_node_groups

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_control_plane = {
      description                   = "Control plane to node ephemeral ports"
      protocol                      = "-1"
      from_port                     = 1024
      to_port                       = 65535
      type                          = "ingress"
      source_cluster_security_group = true
    }


    # Cilium-specific rules
    ingress_cilium_vxlan = {
      description = "Cilium VXLAN overlay"
      protocol    = "udp"
      from_port   = 8472
      to_port     = 8472
      type        = "ingress"
      self        = true
    }

    ingress_cilium_health = {
      description = "Cilium health checks"
      protocol    = "tcp"
      from_port   = 4240
      to_port     = 4240
      type        = "ingress"
      self        = true
    }

    ingress_cilium_hubble = {
      description = "Cilium Hubble"
      protocol    = "tcp"
      from_port   = 4244
      to_port     = 4244
      type        = "ingress"
      self        = true
    }

    # Used for things like filegateway and rds
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# resource "aws_autoscaling_schedule" "evening_schedule" {
#   for_each = var.use_schedules && var.use_schedules ? toset(module.eks.eks_managed_node_groups_autoscaling_group_names) : []
  
#   scheduled_action_name  = "evening-${each.key}"
#   min_size               = 0
#   max_size               = 1
#   desired_capacity       = 0
#   recurrence             = "0 18 * * *"  # Every day at 18:00 UTC (cron format)
#   autoscaling_group_name = each.value
# }

# resource "aws_autoscaling_schedule" "morning_schedule" {
#   for_each = var.use_schedules && var.use_schedules ? toset(module.eks.eks_managed_node_groups_autoscaling_group_names) : []
  
#   scheduled_action_name  = "morning-${each.key}"
#   min_size               = 1
#   max_size               = 15
#   desired_capacity       = 3
#   recurrence             = "0 6 * * *"   # Every day at 06:00 UTC (cron format)
#   autoscaling_group_name = each.value
# }