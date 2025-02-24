#!/bin/sh

echo "RUNNING IN ENVIRONMENT: $ENV"
echo "NODE IDENTIFIER: $NODE_IDENTIFIER"

TERRAFORM_DIR="/usr/src/app/terraform/infrastructure"
cd $TERRAFORM_DIR
VAR_FILE="$TERRAFORM_DIR/node.tfvars"
BACKEND_FILE="$TERRAFORM_DIR/node.tfbackend"
OUTPUT_FILE="$TERRAFORM_DIR/outputs.json"

export AWS_ACCESS_KEY_ID=$2
export AWS_SECRET_ACCESS_KEY=$3
export AWS_SESSION_TOKEN=$4

echo "Creating backend config"
  /bin/cat > $BACKEND_FILE <<EOL
bucket  = "tfstate-$1"
key = "$ENV/$NODE_IDENTIFIER/terraform.tfstate"
EOL

echo "Creating tfvars config"
  /bin/cat > $VAR_FILE <<EOL
account_id = "$1"
region = "$AWS_DEFAULT_REGION"
env = "$ENV"
node_identifier = "$NODE_IDENTIFIER"
wm_cpu = "${WM_CPU:-2048}"
wm_memory = "${WM_MEMORY:-4096}"
az = ["a", "b", "c", "d", "e", "f"]
workflow_manager_image_tag = "$WM_TAG"
viz_cpu = "${VIZ_CPU:-2048}"
viz_memory = "${VIZ_MEMORY:-4096}"
visualization_image_tag = "$VIZ_TAG"
EOL

echo "Running init and plan ..."
export TF_LOG_PATH="error.log"
export TF_LOG=TRACE
terraform init -force-copy -backend-config=$BACKEND_FILE
terraform plan -out=tfplan -var-file=$VAR_FILE

echo "Running apply ..."
terraform apply tfplan
terraform output -json > $OUTPUT_FILE

cat error.log
echo "DONE RUNNING IN ENVIRONMENT: $ENV"