#!/usr/bin/env bash

# Script to walk a directory and run OpenTofu commands with YAML config
# Added state backup to S3 functionality
# Added reverse order processing for destroy operations

# Set default values
COMMAND=""
TARGET_DIR="."
EXCLUDE_DIRS="\.terraform"  # Default exclude .terraform directories
SEQUENTIAL=true
INIT_FIRST=true
CONFIG_FILE="config.yaml"  # Default config file location
AUTO_RESET=false           # Default is not to auto-reset files
BACKUP_STATE=false         # Default is not to backup state files to S3

# Required tools
REQUIRED_TOOLS=("tofu" "find" "grep" "sort" "yq" "sed" "awk")


# =====================================
# Configuration & Setup Functions
# =====================================

# Print usage information
function usage() {
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  plan                      Run tofu plan"
    echo "  apply                     Run tofu apply"
    echo "  destroy                   Run tofu destroy"
    echo "  init                      Run tofu init"
    echo "  validate                  Run tofu validate"
    echo "  refresh                   Run tofu refresh"
    echo "  import                    Run tofu import"
    echo "  output                    Run tofu output"
    echo "  reset                     Reset modified files to original state"
    echo
    echo "Options:"
    echo "  -d, --directory DIR       Directory to scan for OpenTofu files (default: current directory)"
    echo "  -e, --exclude PATTERN     Exclude directories matching pattern (can be used multiple times)"
    echo "                            .terraform directories are always excluded"
    echo "  -p, --parallel            Run OpenTofu commands in parallel (default: sequential)"
    echo "  --no-init                 Skip tofu init (default: run init)"
    echo "  --config FILE             Path to YAML config file (default: ./config.yaml)"
    echo "  --auto-reset              Automatically reset files before processing"
    echo "  --backup-state            Backup state files to S3 after apply/destroy/import"
    echo "  -h, --help                Show this help message"
    echo
    echo "Examples:"
    echo "  $0 apply                  # Run tofu apply on all directories"
    echo "  $0 plan -d /path/to/tf    # Run tofu plan in specific directory"
    echo "  $0 apply -e _*            # Run apply but exclude directories starting with _"
    echo "  $0 plan --config /path/to/config.yaml  # Use specific config file"
    exit 1
}

# Set OS-specific commands - fixes a mac issue
function set_commands() {
    if [[ $(uname -s) == "Linux"* ]]; then
        SED_CMD="sed -i"
    else
        SED_CMD="sed -i ''"
    fi
}

# Check if required tools are installed
function check_requirements() {
    local missing=()
    
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo "Error: Required tools not installed: ${missing[*]}"
        echo "Please install the missing tools before running this script."
        
        if [[ "${missing[*]}" =~ "yq" ]]; then
            echo "For yq installation instructions, visit: https://github.com/mikefarah/yq#install"
        fi
        
        if [[ "${missing[*]}" =~ "tofu" ]]; then
            echo "For OpenTofu installation instructions, visit: https://opentofu.org/docs/intro/install/"
        fi
        
        exit 1
    fi
}

# Function to read config value from YAML
function get_config() {
    local key="$1"
    local default="$2"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$default"
        return
    fi
    
    local value=$(yq eval ".$key" "$CONFIG_FILE")
    
    if [ "$value" == "null" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# =====================================
# File Management Functions
# =====================================
# Function to reset provider files to original state
function reset_files() {
    local target_dir="$1"
    local count=0
    
    echo "🔄 Resetting modified files in $target_dir..."
    
    # Find all providers.tf files
    local provider_files=$(find "$target_dir" -name "providers.tf" -type f | grep -v "\.terraform")
    
    for file in $provider_files; do
        # Check if backup exists
        if [ -f "${file}.orig" ]; then
            echo "   - Restoring original: $file"
            cp "${file}.orig" "$file"
            echo "   - Removing backup: ${file}.orig"
            rm "${file}.orig"
            count=$((count+1))
        else
            # Create backup if it doesn't exist
            echo "   - Creating backup: ${file}.orig"
            cp "$file" "${file}.orig"
        fi
    done

    # Find all terraform.tfvars files
    local tfvars_files=$(find "$target_dir" -name "terraform.tfvars" -type f | grep -v "\.terraform")
    
    for file in $tfvars_files; do
        # Check if backup exists
        if [ -f "${file}.orig" ]; then
            echo "   - Restoring original: $file"
            cp "${file}.orig" "$file"
            echo "   - Removing backup: ${file}.orig"
            rm "${file}.orig"
            count=$((count+1))
        else
            # Create backup if it doesn't exist
            echo "   - Creating backup: ${file}.orig"
            cp "$file" "${file}.orig"
        fi
    done
    
    # Clean up any empty suffix files (terraform.tfvars'')
    local empty_suffix_files=$(find "$target_dir" -name "*.tfvars''" -o -name "*.tf''" | grep -v "\.terraform")
    
    for file in $empty_suffix_files; do
        echo "   - Removing empty suffix file: $file"
        rm "$file"
    done
    
    if [ $count -eq 0 ]; then
        echo "   No files were reset (no .orig backups found)"
        echo "   Backups were created for future resets"
    else
        echo "   Reset $count files to original state"
        echo "   Removed backup files"
    fi
}

# Function to backup state files to S3
function backup_state_to_s3() {
    local dir="$1"
    local bucket="$2"
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local dir_name=$(basename "$(pwd)")
    
    if [ -f "terraform.tfstate" ]; then
        echo "📦 Backing up terraform.tfstate to S3..."
        aws s3 cp terraform.tfstate "s3://${bucket}/state-backups/${dir_name}-${timestamp}.tfstate"
        if [ $? -eq 0 ]; then
            echo "   ✅ State backup successful"
        else
            echo "   ❌ State backup failed"
        fi
    else
        echo "   ⚠️ No local state file found to backup"
    fi
}

# Function to update configuration files
function update_config_file() {
    local file="$1"
    local orig_file="${file}.orig"
    
    echo "🔧 Updating $file configuration..."
    
    # Create backup of original file if it doesn't exist
    if [ ! -f "$orig_file" ]; then
        echo "   - Creating backup: $orig_file"
        cp "$file" "$orig_file"
    fi
    
    # Process S3 bucket settings
    if [ -n "$TERRAFORM_STATE_BUCKET" ] && grep -q "<TERRAFORM_STATE_BUCKET>" "$file"; then
        echo "   - Setting S3 bucket to $TERRAFORM_STATE_BUCKET"
        $SED_CMD "s|<TERRAFORM_STATE_BUCKET>|$TERRAFORM_STATE_BUCKET|g" "$file"
    fi
    
    # Process AWS region settings
    if [ -n "$AWS_REGION" ] && grep -q "<AWS_REGION>" "$file"; then
        echo "   - Setting AWS region to $AWS_REGION"
        $SED_CMD "s|<AWS_REGION>|$AWS_REGION|g" "$file"
    fi
    
    # Process AWS profile settings
    if [ -n "$AWS_PROFILE" ] && grep -q "<AWS_PROFILE>" "$file"; then
        echo "   - Setting AWS profile to $AWS_PROFILE"
        $SED_CMD "s|<AWS_PROFILE>|$AWS_PROFILE|g" "$file"
    fi
    
    # Process VPC name settings
    if [ -n "$VPC_NAME" ] && grep -q "<VPC_NAME>" "$file"; then
        echo "   - Setting VPC name to $VPC_NAME"
        $SED_CMD "s|<VPC_NAME>|$VPC_NAME|g" "$file"
    fi
    
    # Process legacy S3 tag (for backward compatibility)
    if [ -n "$TERRAFORM_STATE_BUCKET" ] && grep -q "<s3>" "$file"; then
        echo "   - Setting legacy S3 tag to $TERRAFORM_STATE_BUCKET"
        $SED_CMD "s|<s3>|$TERRAFORM_STATE_BUCKET|g" "$file"
    fi
}

# =====================================
# OpenTofu Operations
# =====================================
# Function to run a OpenTofu command in a directory
function run_tofu() {
    local dir="$1"
    local cmd="$2"
    
    echo "=================================================="
    echo "📁 Processing: $dir"
    echo "=================================================="
    
    # Change to the directory
    pushd "$dir" > /dev/null
    
    # Auto-reset provider files if enabled
    if [ "$AUTO_RESET" = true ]; then
        for config_file in "providers.tf" "terraform.tfvars"; do
            if [ -f "$config_file" ]; then
                if [ -f "${config_file}.orig" ]; then
                    echo "🔄 Auto-resetting ${config_file} to original state"
                    cp "${config_file}.orig" "$config_file"
                else
                    echo "🔄 Creating backup of ${config_file} for future resets"
                    cp "$config_file" "${config_file}.orig"
                fi
            fi
        done
    fi
    
    # Update configuration files
    for config_file in "providers.tf" "terraform.tfvars"; do
        if [ -f "$config_file" ]; then
            update_config_file "$config_file"
        fi
    done
    
    # Run tofu init if needed
    if [ "$INIT_FIRST" = true ]; then
        if [ "$INIT_RECONFIGURE" = "true" ]; then
            echo "🚀 Running: tofu init -reconfigure"
            tofu init -reconfigure
        else
            echo "🚀 Running: tofu init"
            tofu init
        fi
        
        if [ $? -ne 0 ]; then
            echo "❌ OpenTofu init failed in $dir"
            popd > /dev/null
            return 1
        fi
    fi
    
    # Run the specified OpenTofu command
    echo "🚀 Running: tofu $cmd"
    tofu $cmd
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -ne 0 ]; then
        echo "❌ OpenTofu $cmd failed in $dir with exit code $EXIT_CODE"
    else
        echo "✅ OpenTofu $cmd completed successfully in $dir"
        
        # Backup state file to S3 if enabled and we're using a command that modifies state
        if [ "$BACKUP_STATE" = true ] && [ -n "$TERRAFORM_STATE_BUCKET" ] && [[ "$cmd" == "apply"* || "$cmd" == "destroy"* || "$cmd" == "import"* ]]; then
            backup_state_to_s3 "$dir" "$TERRAFORM_STATE_BUCKET"
        fi
    fi
    
    # Return to the original directory
    popd > /dev/null
    
    return $EXIT_CODE
}

# =====================================
# FluxCD Operations
# =====================================
# Function to bootstrap Flux after OpenTofu completes
function bootstrap_flux() {
    local cluster_name="$1"
    local github_owner="$2"
    local github_repo="$3"
    local github_token="$4"
    
    echo "=================================================="
    echo "📦 Bootstrapping Flux on cluster: $cluster_name"
    echo "=================================================="
    
    # Ensure kubeconfig is properly configured for the cluster
    aws eks update-kubeconfig --name "$cluster_name" --region "$AWS_REGION" --profile "$AWS_PROFILE"
    
    # Bootstrap Flux with GitHub repository
    flux bootstrap github \
      --owner="$github_owner" \
      --repository="$github_repo" \
      --branch=main \
      --path=clusters/"$cluster_name" \
      --token-auth \
      --personal
    
    echo "✅ Flux bootstrapped successfully on $cluster_name"
}

# =====================================
# Main Functions
# =====================================

# Process reset command directly
function run_reset() {
    reset_files "$TARGET_DIR"
    exit 0
}

# Process OpenTofu operations
function run_operations() {
    # Inform about state backup if enabled
    if [ "$BACKUP_STATE" = true ]; then
        if [ -n "$TERRAFORM_STATE_BUCKET" ]; then
            echo "State backup to S3 enabled: $TERRAFORM_STATE_BUCKET"
        else
            echo "⚠️ State backup to S3 was requested but no S3 bucket was specified"
            echo "   Please set terraform_state_bucket in your config file"
            BACKUP_STATE=false
        fi
    fi

    # Find all directories containing *.tf files, excluding .terraform directories
    echo "Finding OpenTofu directories..."
    TOFU_DIRS=$(find "$TARGET_DIR" -type f -name "*.tf" | grep -v "\.terraform" | sed 's|/[^/]*$||' | sort | uniq)

    # If no OpenTofu directories found, exit
    if [ -z "$TOFU_DIRS" ]; then
        echo "No OpenTofu directories found in '$TARGET_DIR'"
        exit 0
    fi

    # Filter out excluded directories
    if [ -n "$EXCLUDE_DIRS" ]; then
        TOFU_DIRS=$(echo "$TOFU_DIRS" | grep -v -E "$EXCLUDE_DIRS")
    fi

    # Sort directories 
    if [[ "$COMMAND" == "destroy"* ]]; then
        # For destroy commands, sort in reverse order
        echo "🔄 Using reverse order for destroy command..."
        SORTED_DIRS=$(echo "$TOFU_DIRS" | sort -V -r)
    else
        # For other commands, sort in normal order
        SORTED_DIRS=$(echo "$TOFU_DIRS" | sort -V)
    fi

    # Run OpenTofu commands
    if [ "$SEQUENTIAL" = true ]; then
        # Run commands sequentially
        echo "Running OpenTofu $COMMAND sequentially in directories..."
        
        for dir in $SORTED_DIRS; do
            run_tofu "$dir" "$COMMAND"
            if [ $? -ne 0 ]; then
                echo "⚠️ Stopping due to error in $dir"
                exit 1
            fi
        done
    else
        # Run commands in parallel
        echo "Running OpenTofu $COMMAND in parallel across directories..."
        
        pids=()
        for dir in $SORTED_DIRS; do
            run_tofu "$dir" "$COMMAND" &
            pids+=($!)
        done
        
        # Wait for all processes to complete
        EXIT_CODE=0
        for pid in ${pids[@]}; do
            wait $pid
            if [ $? -ne 0 ]; then
                EXIT_CODE=1
            fi
        done
        
        if [ $EXIT_CODE -ne 0 ]; then
            echo "⚠️ One or more OpenTofu commands failed"
            exit 1
        fi
    fi

    echo "✨ All OpenTofu operations completed"
    
    # Handle Flux bootstrap if needed
    if [ "$COMMAND" == "apply" ]; then
        # Read Flux configuration from config.yaml
        FLUX_ENABLED=$(get_config "flux.enabled" "false")
        
        if [ "$FLUX_ENABLED" == "true" ]; then
            CLUSTER_NAME=$(get_config "cluster_name" "")
            GITHUB_OWNER=$(get_config "flux.github_owner" "")
            GITHUB_REPO=$(get_config "flux.github_repo" "")
            GITHUB_TOKEN=$(get_config "flux.github_token" "")
            
            if [ -n "$CLUSTER_NAME" ] && [ -n "$GITHUB_OWNER" ] && [ -n "$GITHUB_REPO" ] && [ -n "$GITHUB_TOKEN" ]; then
                # Export GitHub token for Flux
                export GITHUB_TOKEN="$GITHUB_TOKEN"
                
                # Bootstrap Flux
                bootstrap_flux "$CLUSTER_NAME" "$GITHUB_OWNER" "$GITHUB_REPO" "$GITHUB_TOKEN"
            else
                echo "⚠️ Missing required Flux configuration. Skipping Flux bootstrap."
            fi
        fi
    fi
}

# =====================================
# Core Operations
# =====================================

# Initialize OS-specific commands
set_commands

# Check for required tools
check_requirements

# Parse main command first
if [ $# -eq 0 ]; then
    # Show help if no arguments are provided
    echo "No command specified. Showing help:"
    usage
fi

# Extract the main command
case "$1" in
    plan|apply|destroy|init|validate|refresh|import|output)
        COMMAND="$1"
        shift
        ;;
    reset)
        # Handle reset command separately
        shift
        TARGET_DIR="."  # Default to current directory
        # Parse any additional options for reset command
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -d|--directory)
                    TARGET_DIR="$2"
                    shift 2
                    ;;
                *)
                    echo "Unknown option for reset command: $1"
                    usage
                    ;;
            esac
        done
        run_reset
        exit 0
        ;;
    -h|--help)
        usage
        ;;
    *)
        echo "Unknown command: $1"
        usage
        ;;
esac

# Parse additional options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--directory)
            TARGET_DIR="$2"
            shift 2
            ;;
        -e|--exclude)
            if [ -z "$EXCLUDE_DIRS" ]; then
                EXCLUDE_DIRS="$2"
            else
                EXCLUDE_DIRS="$EXCLUDE_DIRS|$2"
            fi
            shift 2
            ;;
        -p|--parallel)
            SEQUENTIAL=false
            shift
            ;;
        --no-init)
            INIT_FIRST=false
            shift
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --auto-reset)
            AUTO_RESET=true
            shift
            ;;
        --backup-state)
            BACKUP_STATE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Warning: Config file '$CONFIG_FILE' not found. Using default values."
fi

# Check if directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist"
    exit 1
fi

# Read configuration values
AWS_PROFILE=$(get_config "aws_profile" "default")
AWS_REGION=$(get_config "aws_region" "us-east-1")
TERRAFORM_STATE_BUCKET=$(get_config "terraform_state_bucket" "")
SSH_PRIVATE_KEY=$(get_config "ssh_private_key" "$HOME/.ssh/id_rsa")
SSH_PUBLIC_KEY=$(get_config "ssh_public_key" "$HOME/.ssh/id_rsa.pub")
OS_TYPE=$(get_config "os_type" "amzn")
OS_VERSION=$(get_config "os_version" "2")
EKS_VERSION=$(get_config "eks_version" "1.28")
PACKER_VERBOSE=$(get_config "packer_verbose" "false")
INIT_RECONFIGURE=$(get_config "init_reconfigure" "false")
VPC_NAME=$(get_config "vpc_name" "")

# Check if auto_reset is defined in config and override command line flag
CONFIG_AUTO_RESET=$(get_config "auto_reset" "false")
if [ "$CONFIG_AUTO_RESET" = "true" ]; then
    AUTO_RESET=true
fi

# Check if backup_state is defined in config and override command line flag
CONFIG_BACKUP_STATE=$(get_config "backup_state" "false")
if [ "$CONFIG_BACKUP_STATE" = "true" ]; then
    BACKUP_STATE=true
fi

# Export configuration as environment variables for OpenTofu
export TF_VAR_aws_profile="$AWS_PROFILE"
export TF_VAR_terraform_state_bucket="$TERRAFORM_STATE_BUCKET"
export TF_VAR_ssh_private_key="$SSH_PRIVATE_KEY"
export TF_VAR_ssh_public_key="$SSH_PUBLIC_KEY"
export TF_VAR_os_type="$OS_TYPE"
export TF_VAR_os_version="$OS_VERSION"
export TF_VAR_eks_version="$EKS_VERSION"
export TF_VAR_packer_verbose="$PACKER_VERBOSE"
export TF_VAR_vpc_name="$VPC_NAME"

# Configure AWS CLI profile if specified
if [ -n "$AWS_PROFILE" ]; then
    export AWS_PROFILE="$AWS_PROFILE"
    echo "Using AWS Profile: $AWS_PROFILE"
fi

# Configure OpenTofu backend S3 bucket if specified
if [ -n "$TERRAFORM_STATE_BUCKET" ]; then
    echo "Using OpenTofu state bucket: $TERRAFORM_STATE_BUCKET"
fi

# Print VPC Name if specified
if [ -n "$VPC_NAME" ]; then
    echo "Using VPC Name: $VPC_NAME"
fi

# Run operations
run_operations