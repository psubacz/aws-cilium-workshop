################################################################################
# References
################################################################################
# - https://github.com/cilium/cilium/tree/v1.16.9
# - https://docs.cilium.io/en/v1.17/network/kubernetes/kubeproxy-free/#kubeproxy-free
# - https://docs.cilium.io/en/latest/network/clustermesh/clustermesh/

################################################################################
# Locals
################################################################################
locals {
  # cilium_chart_version = "1.17.3" #appVersion
  cilium_chart_version = "1.16.9" #appVersion
}

# ################################################################################
# # Variables
# ################################################################################

variable "use_cilium" {
  type        = bool
  default     = false
  description = "Whether to install use_karpenter."
}
variable "use_cilium_helper_cron" {
  type        = bool
  default     = false
  description = "Whether to install use_karpenter."
}

variable "remove_kubeproxy" {
  type        = bool
  default     = true
  description = "Whether to install use_karpenter."
}
variable "remove_aws_cni" {
  type        = bool
  default     = false
  description = "Whether to install use_karpenter."
}



################################################################################
# K8S Installations
################################################################################
resource "aws_iam_policy" "cilium_operator_policy" {
  name        = "cilium-operator-policy"
  description = "Policy for Cilium Operator to manage EC2 network interfaces"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "CiliumOperator"
        Effect    = "Allow"
        Action    = [
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeSecurityGroups",
          "ec2:CreateNetworkInterface",
          "ec2:AttachNetworkInterface",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:AssignPrivateIpAddresses",
          "ec2:CreateTags",
          "ec2:UnassignPrivateIpAddresses",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeTags",
          "ec2:UnassignPrivateIpAddresses",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes"
        ]
        Resource  = ["*"]
      }
    ]
  })
  
  tags = {
    Name = "cilium-operator-policy"
  }
}

module "cilium_operator_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.0.0"

  role_name                  = "${var.cluster_name}-cilium_operator_role"
  force_detach_policies      = false
  assume_role_condition_test = "StringLike"
  role_policy_arns = {
    "policy" : aws_iam_policy.cilium_operator_policy.arn,
  }

  oidc_providers = {
    (var.cluster_name) = {
      provider_arn               = data.aws_iam_openid_connect_provider.selected.arn
      namespace_service_accounts = ["kube-system:*"]
    }
  }
  depends_on = [ aws_iam_policy.cilium_operator_policy ]
}
resource "null_resource" "patch_out_aws_cni" {
    count = var.remove_aws_cni && var.use_cilium ? 1 : 0
    provisioner "local-exec" {
    command = <<-EOT
      kubectl -n kube-system patch daemonset aws-node --type='strategic' -p='{"spec":{"template":{"spec":{"nodeSelector":{"io.cilium/aws-node-enabled":"true"}}}}}'
    EOT
  }
}

resource "null_resource" "patch_out_kube_proxy" {
  count = var.remove_kubeproxy && var.use_cilium ? 1 : 0
    provisioner "local-exec" {
    command = <<-EOT
      kubectl -n kube-system patch daemonset kube-proxy --type='strategic' -p='{"spec":{"template":{"spec":{"nodeSelector":{"io.cilium/kube-proxy-enabled":"true"}}}}}'
    EOT
  }
}

resource "time_sleep" "cilium_wait" {
  count = var.use_cilium ? 1 : 0

  destroy_duration = "30s"
  create_duration  = "30s"

  triggers = {
    cilium = module.cilium_operator_role.iam_role_arn
  }

  depends_on = [
    module.cilium_operator_role
  ]
}


resource "helm_release" "cilium_cni" {
  count = var.use_cilium ? 1 : 0
  
  name       = "cilium-${local.cilium_chart_version}"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = local.cilium_chart_version

  namespace = "kube-system"

  values = [
    templatefile(
      "values/cilium-eni.yaml", 
      {
        cluster_name = "${var.cluster_name}"
        eks_api_endpoint = local.eks_api_endpoint,
        eks_api_port = local.eks_api_port
        irsa_oidc_provider_arn = module.cilium_operator_role.iam_role_arn
        AWS_REGION = var.region
      }
    )
  ]
  depends_on = [ 
    module.cilium_operator_role,
    helm_release.load_balancer_controller,
    null_resource.patch_out_aws_cni,
    null_resource.patch_out_kube_proxy
   ]
}
resource "null_resource" "restart_existing_pods" {
  count = var.use_cilium ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
        ceps=$(kubectl -n "$ns" get cep -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
        pods=$(kubectl -n "$ns" get pod -o custom-columns=NAME:.metadata.name,NETWORK:.spec.hostNetwork | grep -E '\\s(<none>|false)' | awk '{print $1}' | tr '\n' ' ')
        ncep=$(echo "$pods $ceps" | tr ' ' '\n' | sort | uniq -u | paste -s -d ' ' - || echo "")
        for pod in $ncep; do
          echo "$ns/$pod"
        done
      done
    EOT
  }
  depends_on = [ 
    module.cilium_operator_role,
    helm_release.cilium_cni
  ]
}

resource "null_resource" "restart_existing_cilium_operator" {
  count =  var.use_cilium ? 1 : 0
    provisioner "local-exec" {
    command = <<-EOT
      kubectl -n kube-system rollout restart deployment/cilium-operator
    EOT
  }
    depends_on = [ 
      module.cilium_operator_role,
      helm_release.cilium_cni,
      null_resource.restart_existing_pods

   ]
}

resource "null_resource" "restart_existing_cilium_ds" {
  count =  var.use_cilium ? 1 : 0
    provisioner "local-exec" {
    command = <<-EOT
      kubectl -n kube-system rollout restart ds/cilium
    EOT
  }
    depends_on = [ 
      module.cilium_operator_role,
      helm_release.cilium_cni,
      null_resource.restart_existing_pods,
      null_resource.restart_existing_cilium_operator
      
   ]
}


# resource "null_resource" "restart_existing_pods" {
#   count =  var.use_cilium ? 1 : 0
#     provisioner "local-exec" {
#     command = <<-EOT
#       for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
#           ceps=$(kubectl -n "${ns}" get cep \
#               -o jsonpath='{.items[*].metadata.name}')
#           pods=$(kubectl -n "${ns}" get pod \
#               -o custom-columns=NAME:.metadata.name,NETWORK:.spec.hostNetwork \
#               | grep -E '\s(<none>|false)' | awk '{print $1}' | tr '\n' ' ')
#           ncep=$(echo "${pods} ${ceps}" | tr ' ' '\n' | sort | uniq -u | paste -s -d ' ' -)
#           for pod in $(echo $ncep); do
#             echo "${ns}/${pod}";
#           done
#       done
#     EOT
#   }
#     depends_on = [ 
#       module.cilium_operator_role,
#       helm_release.cilium_cni
#    ]
# }




# resource "kubectl_manifest" "cilium_helper_cronjob" {
#   count = var.use_cilium_helper_cron ? 1 : 0
#   yaml_body = templatefile(
#     "${path.module}/cilium-manifests/cilium-taint-manager-cronjob.yaml",{}
#   )

#   depends_on = [
#     helm_release.cilium_cni
#   ]
# }


# # Resource to delete the kube-proxy addon
# # Wait for Cilium to be fully initialized before removing kube-proxy
# resource "null_resource" "wait_for_cilium_init" {
#   count = var.use_cilium ? 1 : 0
  
#   triggers = {
#     cilium_version_id = helm_release.cilium_cni[0].id
#   }
  
#   provisioner "local-exec" {
#     command = <<-EOT
#       echo "Waiting for Cilium pods to be ready..."
#       kubectl -n kube-system wait --for=condition=ready pod -l k8s-app=cilium --timeout=300
      
#       echo "Verifying Cilium connectivity..."
#       kubectl -n kube-system exec $(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}') -- cilium status --timeout 300

#       echo "Cilium initialization completed successfully"
#     EOT
#   }
  
#   depends_on = [
#     helm_release.cilium_cni
#   ]
# }

# resource "null_resource" "delete_kube_proxy_addon" {
#   count = var.use_cilium && var.remove_kubeproxy ? 1 : 0 
#   triggers = {
#     # Add triggers to prevent unnecessary recreation
#     cluster_name = var.cluster_name
#     cilium_version_id = helm_release.cilium_cni[0].id
#     karpenter_id = helm_release.karpenter[0].id
#     cilium_init_id = null_resource.wait_for_cilium_init[0].id # Wait for Cilium to be fully initialized
#   }
  
#   provisioner "local-exec" {
#     # First check if kube-proxy addon exists before trying to delete it
#     command = <<-EOT
#       if aws eks describe-addon --cluster-name ${var.cluster_name} --region ${var.region} --profile ${var.profile} --addon-name kube-proxy &>/dev/null; then
#         echo "Deleting kube-proxy addon..."
#         aws eks delete-addon --cluster-name ${var.cluster_name} --region ${var.region} --profile ${var.profile} --addon-name kube-proxy
#       else
#         echo "kube-proxy addon doesn't exist or was already removed. Skipping deletion."
#       fi
#     EOT
#   }
  
#   depends_on = [ 
#     helm_release.cilium_cni,
#     helm_release.karpenter,
#     # null_resource.wait_for_cilium_init
#   ]
# }

# resource "null_resource" "cleanup_kubeproxy_rules" {
#   count = var.use_cilium && var.remove_kubeproxy ? 1 : 0 
  
#   provisioner "local-exec" {
#     command = <<-EOT
#       kubectl get nodes -o wide | tail -n +2 | awk '{print $1}' | xargs -I {} \
#       kubectl debug node/{} -it --image=ubuntu -- bash -c "iptables-save | grep -v KUBE | iptables-restore"
#     EOT
#   }
  
#   depends_on = [null_resource.delete_kube_proxy_addon]
# }

# # Verify that Cilium is functioning correctly after kube-proxy removal
# resource "null_resource" "verify_cilium_health" {
#   count = var.use_cilium && var.remove_kubeproxy ? 1 : 0
  
#   triggers = {
#     cleanup_id = null_resource.cleanup_kubeproxy_rules[0].id
#   }
  
#   provisioner "local-exec" {
#     command = <<-EOT
#       echo "Running Cilium connectivity test..."
#       kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/v${local.cilium_chart_version}/examples/kubernetes/connectivity-check/connectivity-check.yaml
      
#       echo "Waiting for connectivity test pods to be ready..."
#       kubectl wait --for=condition=ready pod -l name=connectivity-check --timeout=2m
      
#       echo "Checking Cilium agent status on all nodes..."
#       kubectl -n kube-system get pods -l k8s-app=cilium -o wide
#       NODE_POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
#       kubectl -n kube-system exec $NODE_POD -- cilium status
      
#       echo "Verifying new node initialization with Cilium..."
#       kubectl -n kube-system exec $NODE_POD -- cilium-dbg node list
#     EOT
#   }
  
#   depends_on = [
#     null_resource.cleanup_kubeproxy_rules
#   ]
# }

# # Cleanup connectivity test resources after verification
# resource "null_resource" "cleanup_connectivity_test" {
#   count = var.use_cilium && var.remove_kubeproxy ? 1 : 0
  
#   triggers = {
#     verify_id = null_resource.verify_cilium_health[0].id
#   }
  
#   provisioner "local-exec" {
#     command = "kubectl delete -f https://raw.githubusercontent.com/cilium/cilium/v${local.cilium_chart_version}/examples/kubernetes/connectivity-check/connectivity-check.yaml"
#   }
  
#   depends_on = [
#     null_resource.verify_cilium_health
#   ]
# }