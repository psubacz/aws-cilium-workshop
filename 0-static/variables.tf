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
# Buckets
################################################################################

variable "terraform_state_bucket" {
  type        = string
  description = "The name of the cluster bucket."
}
