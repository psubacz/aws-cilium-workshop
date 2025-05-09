# Karpenter Manifest Templates

This directory contains template files for Karpenter configuration that are used by Terraform to generate Kubernetes manifests.

## Files

- `ec2nodeclass.yaml.tftpl`: Template for EC2NodeClass configuration
- `nodepool.yaml.tftpl`: Template for NodePool configuration with Cilium support
- `nodepool-no-cilium.yaml.tftpl`: Template for NodePool configuration without Cilium

## Usage

These templates are used in the main Terraform configuration with the `templatefile` function instead of directly embedding YAML in the Terraform code. This provides the following benefits:

1. Separation of concerns - infrastructure code vs. application manifests
2. Better readability and maintainability
3. Easier to update manifest configurations separately
4. Version control friendly

Each template accepts variables that are passed in from Terraform:

### EC2NodeClass Template Variables

- `node_iam_role_name`: IAM role name for the nodes
- `cluster_name`: EKS cluster name

### NodePool Template Variables

- `availability_zones`: JSON-encoded array of availability zones

## Adding New Templates

When adding new template files:

1. Create a new .tftpl file with your Kubernetes manifest
2. Use `${variable_name}` syntax for variables that should be templated
3. Reference the template in Terraform using the `templatefile` function
4. Pass the required variables to the template function