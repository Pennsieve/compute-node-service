#!/bin/bash
#
# generate-ecs-terraform.sh
#
# Generates Terraform configuration from an existing AWS ECS cluster.
# This script fetches cluster details via AWS CLI and outputs Terraform HCL.
#
# Usage: ./generate-ecs-terraform.sh <cluster-name> [options]
#
# Options:
#   -r, --region        AWS region (default: uses AWS_DEFAULT_REGION or us-east-1)
#   -o, --output        Output file path (default: stdout)
#   -p, --prefix        Resource name prefix for Terraform (default: cluster name)
#   --profile           AWS CLI profile to use
#   --with-imports      Generate terraform import commands
#   --with-variables    Generate variables.tf content
#   -h, --help          Show this help message

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
OUTPUT_FILE=""
PREFIX=""
PROFILE=""
WITH_IMPORTS=false
WITH_VARIABLES=false

usage() {
    cat << EOF
Usage: $(basename "$0") <cluster-name> [options]

Generates Terraform configuration from an existing AWS ECS cluster.

Arguments:
  cluster-name        Name of the ECS cluster to export

Options:
  -r, --region        AWS region (default: $REGION)
  -o, --output        Output file path (default: stdout)
  -p, --prefix        Resource name prefix for Terraform (default: derived from cluster name)
  --profile           AWS CLI profile to use (default: uses current credentials)
  --with-imports      Generate terraform import commands
  --with-variables    Generate variables.tf content
  -h, --help          Show this help message

Examples:
  $(basename "$0") gpu-workflow-cluster
  $(basename "$0") gpu-workflow-cluster --profile dev-admin -o ecs-gpu.tf --with-imports
  $(basename "$0") gpu-workflow-cluster -r us-east-1 -o ecs-gpu.tf --with-imports
  $(basename "$0") my-cluster --with-variables > my-cluster.tf

EOF
    exit 0
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Parse arguments
CLUSTER_NAME=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -p|--prefix)
            PREFIX="$2"
            shift 2
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --with-imports)
            WITH_IMPORTS=true
            shift
            ;;
        --with-variables)
            WITH_VARIABLES=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            ;;
        *)
            if [[ -z "$CLUSTER_NAME" ]]; then
                CLUSTER_NAME="$1"
            else
                log_error "Unexpected argument: $1"
                usage
            fi
            shift
            ;;
    esac
done

if [[ -z "$CLUSTER_NAME" ]]; then
    log_error "Cluster name is required"
    usage
fi

# Build AWS CLI profile argument
AWS_PROFILE_ARG=""
if [[ -n "$PROFILE" ]]; then
    AWS_PROFILE_ARG="--profile $PROFILE"
    log_info "Using AWS profile: $PROFILE"
fi

# Derive prefix from cluster name if not provided
if [[ -z "$PREFIX" ]]; then
    # Convert cluster-name to snake_case for terraform resource names
    PREFIX=$(echo "$CLUSTER_NAME" | tr '-' '_')
fi

log_info "Fetching ECS cluster: $CLUSTER_NAME in region: $REGION"

# Fetch cluster details
CLUSTER_JSON=$(aws ecs describe-clusters \
    --clusters "$CLUSTER_NAME" \
    --include SETTINGS CONFIGURATIONS TAGS \
    --region "$REGION" \
    $AWS_PROFILE_ARG \
    --output json 2>&1) || {
    log_error "Failed to describe cluster: $CLUSTER_JSON"
    exit 1
}

# Check if cluster exists
CLUSTER_COUNT=$(echo "$CLUSTER_JSON" | jq '.clusters | length')
if [[ "$CLUSTER_COUNT" -eq 0 ]]; then
    log_error "Cluster '$CLUSTER_NAME' not found"
    # Check failures
    FAILURES=$(echo "$CLUSTER_JSON" | jq -r '.failures[]?.reason // empty')
    if [[ -n "$FAILURES" ]]; then
        log_error "Reason: $FAILURES"
    fi
    exit 1
fi

CLUSTER=$(echo "$CLUSTER_JSON" | jq '.clusters[0]')
CLUSTER_ARN=$(echo "$CLUSTER" | jq -r '.clusterArn')

log_info "Found cluster: $CLUSTER_ARN"

# Extract cluster configuration
CLUSTER_SETTINGS=$(echo "$CLUSTER" | jq -c '.settings // []')
CLUSTER_CONFIG=$(echo "$CLUSTER" | jq -c '.configuration // {}')
CLUSTER_TAGS=$(echo "$CLUSTER" | jq -c '.tags // []')
CAPACITY_PROVIDERS=$(echo "$CLUSTER" | jq -r '.capacityProviders // []')
DEFAULT_CAPACITY_STRATEGY=$(echo "$CLUSTER" | jq -c '.defaultCapacityProviderStrategy // []')

# Check for Container Insights
CONTAINER_INSIGHTS=$(echo "$CLUSTER_SETTINGS" | jq -r '.[] | select(.name == "containerInsights") | .value // "disabled"')

# Check for execute command configuration
EXEC_CONFIG=$(echo "$CLUSTER_CONFIG" | jq -c '.executeCommandConfiguration // {}')
EXEC_KMS_KEY=$(echo "$EXEC_CONFIG" | jq -r '.kmsKeyId // empty')
EXEC_LOGGING=$(echo "$EXEC_CONFIG" | jq -r '.logging // "DEFAULT"')
EXEC_LOG_CONFIG=$(echo "$EXEC_CONFIG" | jq -c '.logConfiguration // {}')

# Fetch capacity provider details if using custom ones
CUSTOM_CAPACITY_PROVIDERS=()
for cp in $(echo "$CAPACITY_PROVIDERS" | jq -r '.[]'); do
    if [[ "$cp" != "FARGATE" && "$cp" != "FARGATE_SPOT" ]]; then
        CUSTOM_CAPACITY_PROVIDERS+=("$cp")
    fi
done

# Start generating Terraform
generate_terraform() {
    cat << 'HEADER'
// ============================================================================
// Auto-generated Terraform configuration
// Generated by: generate-ecs-terraform.sh
// ============================================================================

HEADER

    # Generate variables if requested
    if [[ "$WITH_VARIABLES" == true ]]; then
        cat << VARIABLES
// ----------------------------------------------------------------------------
// Variables
// ----------------------------------------------------------------------------

variable "${PREFIX}_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "$CLUSTER_NAME"
}

VARIABLES
    fi

    # Check if we need KMS key
    if [[ -n "$EXEC_KMS_KEY" ]]; then
        cat << KMS
// ----------------------------------------------------------------------------
// KMS Key for ECS Execute Command
// ----------------------------------------------------------------------------

resource "aws_kms_key" "${PREFIX}_cluster" {
  description             = "${PREFIX}_cluster_kms_key"
  deletion_window_in_days = 7
}

KMS
    fi

    # Check if we need CloudWatch log group for execute command
    CW_LOG_GROUP=$(echo "$EXEC_LOG_CONFIG" | jq -r '.cloudWatchLogGroupName // empty')
    if [[ -n "$CW_LOG_GROUP" ]]; then
        cat << CWLOG
// ----------------------------------------------------------------------------
// CloudWatch Log Group for ECS Execute Command
// ----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "${PREFIX}_cluster" {
  name = "$CW_LOG_GROUP"
}

CWLOG
    fi

    # Generate ECS Cluster resource
    cat << CLUSTER_START
// ----------------------------------------------------------------------------
// ECS Cluster
// ----------------------------------------------------------------------------

resource "aws_ecs_cluster" "$PREFIX" {
  name = "$CLUSTER_NAME"
CLUSTER_START

    # Add settings if container insights is enabled
    if [[ "$CONTAINER_INSIGHTS" == "enabled" ]]; then
        cat << SETTINGS

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
SETTINGS
    fi

    # Add execute command configuration if present
    if [[ "$EXEC_LOGGING" != "DEFAULT" ]] || [[ -n "$EXEC_KMS_KEY" ]]; then
        echo ""
        echo "  configuration {"
        echo "    execute_command_configuration {"

        if [[ -n "$EXEC_KMS_KEY" ]]; then
            echo "      kms_key_id = aws_kms_key.${PREFIX}_cluster.arn"
        fi

        echo "      logging    = \"$EXEC_LOGGING\""

        if [[ "$EXEC_LOGGING" == "OVERRIDE" ]]; then
            echo ""
            echo "      log_configuration {"

            CW_ENCRYPTION=$(echo "$EXEC_LOG_CONFIG" | jq -r '.cloudWatchEncryptionEnabled // false')
            if [[ -n "$CW_LOG_GROUP" ]]; then
                echo "        cloud_watch_encryption_enabled = $CW_ENCRYPTION"
                echo "        cloud_watch_log_group_name     = aws_cloudwatch_log_group.${PREFIX}_cluster.name"
            fi

            S3_BUCKET=$(echo "$EXEC_LOG_CONFIG" | jq -r '.s3BucketName // empty')
            if [[ -n "$S3_BUCKET" ]]; then
                S3_ENCRYPTION=$(echo "$EXEC_LOG_CONFIG" | jq -r '.s3EncryptionEnabled // false')
                S3_PREFIX=$(echo "$EXEC_LOG_CONFIG" | jq -r '.s3KeyPrefix // empty')
                echo "        s3_bucket_name          = \"$S3_BUCKET\""
                echo "        s3_bucket_encryption_enabled = $S3_ENCRYPTION"
                if [[ -n "$S3_PREFIX" ]]; then
                    echo "        s3_key_prefix           = \"$S3_PREFIX\""
                fi
            fi

            echo "      }"
        fi

        echo "    }"
        echo "  }"
    fi

    # Add tags if present
    TAG_COUNT=$(echo "$CLUSTER_TAGS" | jq 'length')
    if [[ "$TAG_COUNT" -gt 0 ]]; then
        echo ""
        echo "  tags = {"
        echo "$CLUSTER_TAGS" | jq -r '.[] | "    \(.key) = \"\(.value)\""'
        echo "  }"
    fi

    echo "}"

    # Generate capacity provider associations if using non-default providers
    CP_COUNT=$(echo "$CAPACITY_PROVIDERS" | jq 'length')
    STRATEGY_COUNT=$(echo "$DEFAULT_CAPACITY_STRATEGY" | jq 'length')

    if [[ "$CP_COUNT" -gt 0 ]] || [[ "$STRATEGY_COUNT" -gt 0 ]]; then
        cat << CP_ASSOC_START

// ----------------------------------------------------------------------------
// Capacity Provider Association
// ----------------------------------------------------------------------------

resource "aws_ecs_cluster_capacity_providers" "$PREFIX" {
  cluster_name = aws_ecs_cluster.${PREFIX}.name

CP_ASSOC_START

        # List capacity providers
        echo "  capacity_providers = ["
        echo "$CAPACITY_PROVIDERS" | jq -r '.[] | "    \"\(.)\","'
        echo "  ]"

        # Default capacity provider strategy
        if [[ "$STRATEGY_COUNT" -gt 0 ]]; then
            echo ""
            for i in $(seq 0 $((STRATEGY_COUNT - 1))); do
                STRATEGY=$(echo "$DEFAULT_CAPACITY_STRATEGY" | jq ".[$i]")
                CP_NAME=$(echo "$STRATEGY" | jq -r '.capacityProvider')
                WEIGHT=$(echo "$STRATEGY" | jq -r '.weight // 0')
                BASE=$(echo "$STRATEGY" | jq -r '.base // 0')

                echo "  default_capacity_provider_strategy {"
                echo "    capacity_provider = \"$CP_NAME\""
                echo "    weight            = $WEIGHT"
                if [[ "$BASE" -gt 0 ]]; then
                    echo "    base              = $BASE"
                fi
                echo "  }"
            done
        fi

        echo "}"
    fi

    # Generate custom capacity providers (EC2 Auto Scaling)
    for cp in "${CUSTOM_CAPACITY_PROVIDERS[@]}"; do
        log_info "Fetching capacity provider: $cp" >&2

        CP_JSON=$(aws ecs describe-capacity-providers \
            --capacity-providers "$cp" \
            --region "$REGION" \
            $AWS_PROFILE_ARG \
            --output json 2>/dev/null) || continue

        CP_DETAILS=$(echo "$CP_JSON" | jq '.capacityProviders[0] // empty')
        if [[ -z "$CP_DETAILS" || "$CP_DETAILS" == "null" ]]; then
            log_warn "Could not fetch details for capacity provider: $cp" >&2
            continue
        fi

        ASG_ARN=$(echo "$CP_DETAILS" | jq -r '.autoScalingGroupProvider.autoScalingGroupArn // empty')
        MANAGED_SCALING=$(echo "$CP_DETAILS" | jq -c '.autoScalingGroupProvider.managedScaling // {}')
        MANAGED_TERMINATION=$(echo "$CP_DETAILS" | jq -r '.autoScalingGroupProvider.managedTerminationProtection // "DISABLED"')

        CP_TF_NAME=$(echo "$cp" | tr '-' '_')

        cat << CP_RESOURCE

// ----------------------------------------------------------------------------
// Capacity Provider: $cp
// ----------------------------------------------------------------------------

resource "aws_ecs_capacity_provider" "$CP_TF_NAME" {
  name = "$cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn = "$ASG_ARN"
    managed_termination_protection = "$MANAGED_TERMINATION"

CP_RESOURCE

        MS_STATUS=$(echo "$MANAGED_SCALING" | jq -r '.status // "DISABLED"')
        if [[ "$MS_STATUS" != "DISABLED" ]]; then
            MS_TARGET=$(echo "$MANAGED_SCALING" | jq -r '.targetCapacity // 100')
            MS_MIN=$(echo "$MANAGED_SCALING" | jq -r '.minimumScalingStepSize // 1')
            MS_MAX=$(echo "$MANAGED_SCALING" | jq -r '.maximumScalingStepSize // 10000')
            MS_WARMUP=$(echo "$MANAGED_SCALING" | jq -r '.instanceWarmupPeriod // 300')

            cat << MANAGED_SCALING
    managed_scaling {
      status                    = "$MS_STATUS"
      target_capacity           = $MS_TARGET
      minimum_scaling_step_size = $MS_MIN
      maximum_scaling_step_size = $MS_MAX
      instance_warmup_period    = $MS_WARMUP
    }
MANAGED_SCALING
        fi

        echo "  }"
        echo "}"
    done

    # Generate import commands if requested
    if [[ "$WITH_IMPORTS" == true ]]; then
        cat << IMPORTS

// ============================================================================
// Terraform Import Commands
// ============================================================================
// Run these commands to import existing resources into Terraform state:
//
// terraform import aws_ecs_cluster.$PREFIX $CLUSTER_ARN
IMPORTS

        if [[ -n "$EXEC_KMS_KEY" ]]; then
            echo "// terraform import aws_kms_key.${PREFIX}_cluster $EXEC_KMS_KEY"
        fi

        if [[ -n "$CW_LOG_GROUP" ]]; then
            echo "// terraform import aws_cloudwatch_log_group.${PREFIX}_cluster $CW_LOG_GROUP"
        fi

        if [[ "$CP_COUNT" -gt 0 ]] || [[ "$STRATEGY_COUNT" -gt 0 ]]; then
            echo "// terraform import aws_ecs_cluster_capacity_providers.$PREFIX $CLUSTER_NAME"
        fi

        for cp in "${CUSTOM_CAPACITY_PROVIDERS[@]}"; do
            CP_TF_NAME=$(echo "$cp" | tr '-' '_')
            echo "// terraform import aws_ecs_capacity_provider.$CP_TF_NAME $cp"
        done

        echo "//"
        echo "// ============================================================================"
    fi
}

# Output
if [[ -n "$OUTPUT_FILE" ]]; then
    generate_terraform > "$OUTPUT_FILE"
    log_info "Terraform configuration written to: $OUTPUT_FILE"
else
    generate_terraform
fi

log_info "Done!"
