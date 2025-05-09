################################################################################
# AWS Provider
################################################################################

variable "profile" {
  type        = string
  description = "AWS config profile to use."
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "The AWS region to use."
}

variable "default_tags" {
  type        = map(string)
  default     = {}
  description = "The default tags to apply to AWS resources."
}

################################################################################
# General
################################################################################

variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster to use."
}


################################################################################
# eks blueprint bootstrapping
################################################################################

# variable "install_karpenter" {
#   type        = bool
#   description = "feature gate to install karpenter using blueprint and add to eks auth"
#   default     = false
# }

