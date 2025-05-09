################################################################################
# AWS provider
################################################################################

region  = "us-west-2"
profile = "aether-sandbox-gov"
default_tags = {
  Project    = "Overhead"
  Managed_By = "Terraform via https://gitlab.iap.maxar.com/devops/govcloud-devops-env/-/tree/main/clusters/2-eks"
  Created_By = "Peter Subacz"
}

################################################################################
# General variables
################################################################################
vpc_name     = "terraform"
cluster_name = "terraform"
################################################################################
# EKS
################################################################################

kubernetes_version = "1.32"

cluster_endpoint_public_access = true

# Instance name , On-Demand hourly rate, vCPU, Memory, Storage, Network performance
# t3.small    , $0.0208, 2, 2 GiB, EBS Only, Up to 5 Gigabit, INTEL
# t4g.small   , $0.0168, 2, 2 GiB, EBS Only, Up to 5 Gigabit, ARM
# t4g.large   , $0.0672, 2, 8 GiB, EBS Only, Up to 5 Gigabit,
# Instance Size 	vCPU 	Memory (GiB) 	Instance Storage (GB) 	Network Bandwidth (Gbps) 	EBS Bandwidth (Gbps)
# m7i.large, 2, 8, EBS-Only, Up to 12.5, Up to 10, INTEL x86_64


eks_managed_node_groups = {
  "bootstrap" = {
    min_size     = 2
    max_size     = 4
    desired_size = 2

    instance_types = ["m7i.large"]
    ami_type       = "AL2023_x86_64_STANDARD"

    labels = {
      "dedicated" = "bootstrap"
    }
    taints = [
      {
        key    = "CriticalAddonsOnly"
        value  = "true"
        effect = "NO_SCHEDULE"
      },
      
    ]
    tags = {
      NodeGroup = "bootstrap"
      Cluster   = "devops-28"
    }
  }

  # "bootstrap_arm_fips" = {
  #   min_size     = 2
  #   max_size     = 4
  #   desired_size = 2

  #   ami_type = "BOTTLEROCKET_ARM_64_FIPS"
  #   instance_types = ["t4g.small"]

  #   labels = {
  #     "dedicated" = "bootstrap"
  #   }
  #   taints = [
  #     {
  #       key    = "dedicated"
  #       value  = "bootstrap"
  #       effect = "NO_SCHEDULE"
  #     }
  #   ]
  #   tags = {
  #     NodeGroup = "bootstrap"
  #     Cluster   = "devops-28"
  #   }
  #   enable_bootstrap_user_data = true
  #   bootstrap_extra_args = <<-EOT
  #         [settings.host-containers.admin]
  #         enabled = false
  #         [settings.host-containers.control]
  #         enabled = true
  #         [settings.kernel]
  #         lockdown = "integrity"
  #         [settings.kubernetes.node-labels]
  #         "bottlerocket.aws/updater-interface-version" = "2.0.0"
  #         [settings.kubernetes.node-taints]
  #         "CriticalAddonsOnly" = "true:NoSchedule"
  #       EOT
  # }
}

additional_allowed_cidrs = [
  // Melbourne Office from https://gitlab.iap.maxar.com/devops/terraform-modules/maxar-cidr-blocks/-/blob/main/main.tf?ref_type=heads
  "108.188.194.94/32",
  "68.205.0.193/32",
  "81.180.123.16/32"
]