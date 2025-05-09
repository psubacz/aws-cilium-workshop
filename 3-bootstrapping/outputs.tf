output "karpenter_best_practices" {
  value = "karpenter_best_practices"
  description = "Reference: https://docs.aws.amazon.com/eks/latest/best-practices/karpenter.html" 
}

output "karpenter_examples_nodepool_and_ec2nc" {
  value = "kapenter examples for nodepools and ec2-nodeclasses"
  description = "Reference: https://github.com/aws/karpenter-provider-aws/tree/main/examples/v1" 
}

output "clustermesh_reference" {
  value = "clustermesh_reference"
  description = "Reference: https://docs.cilium.io/en/stable/network/clustermesh/clustermesh/" 
}

output "aws_lbc_reference"{
  value = "aws_lbc_reference"
  description = "https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/"
}

