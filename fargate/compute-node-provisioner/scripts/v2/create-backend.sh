#!/bin/sh

echo "s3 Backend does not exist, creating ..."

cd "/usr/src/app/terraform/s3-backend"

export AWS_ACCESS_KEY_ID=$2
export AWS_SECRET_ACCESS_KEY=$3
export AWS_SESSION_TOKEN=$4

VAR_FILE="/usr/src/app/terraform/s3-backend/s3backend.tfvars"

echo "Creating tfvars config"
  /bin/cat > $VAR_FILE <<EOL
account_id = "$1"
EOL

export TF_LOG_PATH="error.log"
export TF_LOG=TRACE
terraform init
terraform plan -out=tfplan -var-file=$VAR_FILE
terraform apply tfplan
