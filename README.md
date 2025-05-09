# Terraform Bootstraper Script

A Bash utility script designed to automate running Terraform commands across multiple directories with consistent configuration settings.

## Overview

The `bootstraper.sh` script scans directories for Terraform files and runs specified Terraform commands (plan, apply, destroy, etc.) either sequentially or in parallel. It automatically configures provider settings using values from a YAML configuration file.

> **Note:** This process only sets global variables like aws region, profile, and vpc name. IE things that only change if you are bootstrapping from scratch. Module specific *.tfvars should be manually set

## Features

- Scan directories recursively for Terraform files
- Execute Terraform commands in sequential or parallel mode
- Configure AWS profile, region, and S3 backend settings automatically
- Exclude specific directories from execution
- Backup and reset provider files to original state
- Auto-initialize Terraform before running commands
- YAML-based configuration for environment variables

## Requirements

The script requires the following tools to be installed:

- terraform
- find
- grep
- sort
- yq (YAML parser)
- sed
- awk

## Installation

1. Copy the `bootstraper.sh` script to your repository
2. Make it executable:
   ```
   chmod +x bootstraper.sh
   ```
3. Create a `config.yaml` file in the same directory or specify a path with `--config`

## Configuration

Create a `config.yaml` file with the following structure:

```yaml
# AWS configuration
aws_profile: "your-aws-profile"
aws_region: "us-east-1"

# Terraform configuration
terraform_state_bucket: "your-s3-bucket"
init_reconfigure: true  # Use terraform init -reconfigure
auto_reset: true        # Auto reset provider files before each run

# SSH key paths
ssh_private_key: "/path/to/private/key"
ssh_public_key: "/path/to/public/key.pub"

# Additional configurations
os_type: "amzn"
os_version: "2"
eks_version: "1.28"
packer_verbose: "false"
```

### Cilium Config
in `3-bootstrapping/terraform.tfvars` turn features on or off
in `3-bootstrapping/_cilium.tf` on line 151 you can point the helm values file to a different file to use chaining mode or eni with ingress

## Provider Files

The script can automatically update Terraform provider files by replacing placeholder values:

- `<AWS_PROFILE>` - AWS profile from config
- `<AWS_REGION>` - AWS region from config
- `<TERRAFORM_STATE_BUCKET>` - S3 bucket name from config
- `<s3>` - Legacy placeholder for S3 bucket (backward compatibility)

The script automatically backs up provider files before modifying them and can restore them with the `--reset` option.

## Usage

### Basic Usage

```
./bootstraper.sh [options]
```

### Options

- `-c, --command COMMAND` - Terraform command to run (default: plan)
- `-d, --directory DIR` - Directory to scan for Terraform files (default: current directory)
- `-e, --exclude PATTERN` - Exclude directories matching pattern (can be used multiple times)
- `-p, --parallel` - Run Terraform commands in parallel (default: sequential)
- `--no-init` - Skip terraform init (default: run init)
- `--config FILE` - Path to YAML config file (default: ./config.yaml)
- `--reset` - Reset all provider files to original state and exit
- `--auto-reset` - Reset provider files before each run
- `-h, --help` - Show help message

### Examples

Run terraform plan on all directories:
```
./bootstraper.sh -c plan
```

Run terraform apply on a specific directory:
```
./bootstraper.sh -c apply -d /path/to/terraform
```

Run terraform plan but exclude directories starting with an underscore:
```
./bootstraper.sh -c plan -e _*
```

Use a specific config file:
```
./bootstraper.sh -c apply --config /path/to/config.yaml
```

Reset all provider files to their original state:
```
./bootstraper.sh --reset
```

## Directory Structure

The script is designed to work with a linear list of Terraform modules, as shown in the project structure:

```
├── 0-static/
├── 1-vpc/
├── 2-eks/
├── 3-bootstrap/
├── bootstraper.sh
└── config.yaml
```

Directories are processed in numerical order using the `sort -V` command.

## Environment Variables

The script exports the following environment variables for Terraform:

```
TF_VAR_aws_profile
TF_VAR_terraform_state_bucket
TF_VAR_ssh_private_key
TF_VAR_ssh_public_key
TF_VAR_os_type
TF_VAR_os_version
TF_VAR_eks_version
TF_VAR_packer_verbose
AWS_PROFILE
```

## Notes

- The script always excludes `.terraform` directories
- It automatically creates backups of provider files with the `.orig` extension
- When run in sequential mode, the script stops on the first error
- When run in parallel mode, it collects all exit codes and reports failures at the end

## Design References
- [cilium-service-mesh-on-eks](https://github.com/aws-samples/cilium-service-mesh-on-eks?tab=readme-ov-file)
- https://docs.cilium.io/en/stable/network/clustermesh/clustermesh/
- https://docs.cilium.io/en/stable/network/clustermesh/eks-clustermesh-prep/#gs-clustermesh-eks-prep
- https://arthurchiao.art/blog/cilium-clustermesh/
- https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/modules/karpenter/outputs.tf
- https://karpenter.sh/v1.4/concepts/nodeclasses/
- https://github.com/bottlerocket-os/bottlerocket-update-operator/blob/develop/design/1.0.0-release.md
- https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/modules/karpenter/outputs.tf
- https://github.com/aws-samples/cilium-service-mesh-on-eks/tree/main