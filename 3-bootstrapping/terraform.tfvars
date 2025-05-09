################################################################################
# AWS provider
################################################################################

region  = "us-east-2"
profile = "aether-sandbox-gov"
default_tags = {
  Project    = "Overhead"
  Managed_By = "Terraform via https://gitlab.iap.maxar.com/devops/govcloud-devops-env/-/tree/main/clusters/2-eks"
  Created_By = "Peter Subacz"
}

################################################################################
# General variables
################################################################################

cluster_name = "terraform"

## Feature Gates 
use_cilium                        = true
use_cilium_eni                    = true
use_cilium_service_mesh           = false  # stubbed out, not working
use_cilium_aws_chaining           = false  # stubbed out
use_aws_load_balancer_controller  = true
install_ingress_nginx_controller  = true
use_karpenter                     = false

### aws-lbc config
default_ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"