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
# VPC
################################################################################

variable "vpc_name" {
  type        = string
  description = "The vpc name if it should differ from the environment name."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "The cidr block for the VPC."
}

variable "vpc_flow_log_bucket_arn" {
  type        = string
  default     = null
  description = "The ARN of the bucket to log VPC flows to"
}
