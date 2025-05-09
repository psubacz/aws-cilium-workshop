
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

variable "vpc_name" {
  type        = string
  description = "The vpc name if it should differ from the environment name."
}

variable "additional_allowed_cidrs" {
  type        = list(string)
  default     = []
  description = "Any additional allowed cidrs who should be able to access the EKS cluster."
}

################################################################################
# EKS
################################################################################

variable "cluster_name" {
  type        = string
  description = "The cluster name if it should differ from the environment name."
}

variable "kubernetes_version" {
  type        = string
  description = "The version of kubernetes to use."
}

variable "eks_managed_node_groups" {
  type        = map(any)
  description = "The set of EKS managed node groups to create."
}

variable "cluster_endpoint_public_access" {
  type        = bool
  default     = false
  description = "Whether to enable public access to the EKS cluster, locked down to VPN IPs."
}
variable "use_schedules" {
  type        = bool
  default     = true
  description = "Whether to use schedules in the bootstrap script to save on ec2 costs."
}
