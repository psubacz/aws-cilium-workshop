
output "cluster_name" {
  value       = var.cluster_name
  description = "The name of the EKS cluster."
}

output "region" {
  value       = var.region
  description = "The name of the EKS cluster."
}

output "eks_oidc_provider_arn" {
  value       = module.eks.oidc_provider_arn
  description = "The ARN of the cluster's OIDC provider."
}

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${var.region} --profile ${var.profile} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "ec2_spot_instance_linked_account" {
  description = "Unless your AWS account has already onboarded to EC2 Spot, you will need to create the service linked role to avoid the"
  value       = "aws iam --region ${var.region} --profile ${var.profile} create-service-linked-role --aws-service-name spot.amazonaws.com || true"
}
