# EKS

This stack creates an EKS cluster in the provided VPC, including setting up cross-account OIDC issuers and
a base nodegroup upon which the bootstrap controllers can be run.


## Configuration
Updated the AWS VPC CNI configuration to run in "zero" mode, which allows Cilium to take over networking
Added Cilium-specific security group rules to enable proper communication between nodes

## Reference
- [AWS Ondemand Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [AWS Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [AmazonEKS-Nodegroup](https://docs.aws.amazon.com/eks/latest/APIReference/API_Nodegroup.html#AmazonEKS-Type-Nodegroup-amiType)

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.14.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 5.29.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | 4.0.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.29.0 |
| <a name="provider_aws.commercial"></a> [aws.commercial](#provider\_aws.commercial) | 5.29.0 |
| <a name="provider_aws.sandbox"></a> [aws.sandbox](#provider\_aws.sandbox) | 5.29.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.0.5 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | 19.20.0 |
| <a name="module_maxar_ips"></a> [maxar\_ips](#module\_maxar\_ips) | gitlab.iap.maxar.com/devops/maxar-cidr-blocks/null | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_iam_openid_connect_provider.oidc_provider](https://registry.terraform.io/providers/hashicorp/aws/5.29.0/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_openid_connect_provider.sandbox_oidc_provider](https://registry.terraform.io/providers/hashicorp/aws/5.29.0/docs/resources/iam_openid_connect_provider) | resource |
| [aws_default_tags.current](https://registry.terraform.io/providers/hashicorp/aws/5.29.0/docs/data-sources/default_tags) | data source |
| [aws_nat_gateway.ngw](https://registry.terraform.io/providers/hashicorp/aws/5.29.0/docs/data-sources/nat_gateway) | data source |
| [aws_nat_gateways.ngws](https://registry.terraform.io/providers/hashicorp/aws/5.29.0/docs/data-sources/nat_gateways) | data source |
| [aws_partition.commercial](https://registry.terraform.io/providers/hashicorp/aws/5.29.0/docs/data-sources/partition) | data source |
| [aws_partition.sandbox](https://registry.terraform.io/providers/hashicorp/aws/5.29.0/docs/data-sources/partition) | data source |
| [aws_subnets.private](https://registry.terraform.io/providers/hashicorp/aws/5.29.0/docs/data-sources/subnets) | data source |
| [aws_vpc.selected](https://registry.terraform.io/providers/hashicorp/aws/5.29.0/docs/data-sources/vpc) | data source |
| [tls_certificate.eks_oidc](https://registry.terraform.io/providers/hashicorp/tls/4.0.5/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_allowed_cidrs"></a> [additional\_allowed\_cidrs](#input\_additional\_allowed\_cidrs) | Any additional allowed cidrs who should be able to access the EKS cluster. | `list(string)` | `[]` | no |
| <a name="input_cluster_endpoint_public_access"></a> [cluster\_endpoint\_public\_access](#input\_cluster\_endpoint\_public\_access) | Whether to enable public access to the EKS cluster, locked down to VPN IPs. | `bool` | `false` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The cluster name if it should differ from the environment name. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | The default tags to apply to AWS resources. | `map(string)` | `{}` | no |
| <a name="input_eks_managed_node_groups"></a> [eks\_managed\_node\_groups](#input\_eks\_managed\_node\_groups) | The set of EKS managed node groups to create. | `map(any)` | n/a | yes |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | The version of kubernetes to use. | `string` | n/a | yes |
| <a name="input_profile"></a> [profile](#input\_profile) | AWS config profile to use. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The AWS region to use. | `string` | `"us-east-1"` | no |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | The vpc name if it should differ from the environment name. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_eks_name"></a> [eks\_name](#output\_eks\_name) | The name of the EKS cluster. |
| <a name="output_eks_oidc_provider_arn"></a> [eks\_oidc\_provider\_arn](#output\_eks\_oidc\_provider\_arn) | The ARN of the cluster's OIDC provider. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
