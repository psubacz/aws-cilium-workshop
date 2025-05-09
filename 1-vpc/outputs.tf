
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The ID of the VPC created."
}

output "nat_public_ips" {
  value       = module.vpc.nat_public_ips
  description = "The public IP addresses for the VPC's NAT gateway."
}

output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "The private subnets in the VPC."
}

output "public_subnets" {
  value       = module.vpc.public_subnets
  description = "The public subnets in the VPC."
}

output "azs" {
  value       = module.vpc.azs
  description = "The availability zones used by the VPC."
}
