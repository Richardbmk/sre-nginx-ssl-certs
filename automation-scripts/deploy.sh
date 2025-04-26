#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Deploy the complete infrastructure to AWS
# This script assumes that the AWS CLI is installed and configured with the necessary permissions.
# It also assumes that the user has the necessary permissions to create and manage EC2 instances, security groups, and IAM roles.

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null
then
    echo "AWS CLI could not be found. Please install it and configure it with your AWS credentials."
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null
then
    echo "Terraform could not be found. Please install it and configure it with your AWS credentials."
    exit 1
fi

# variables
REGION="${1}"
INSTANCE_NAME="${2}"
DOMAIN="${3}"
EMAIL="${4}"


# Update setup-all.sh with the EMAIL and DOMAIN variables
export EMAIL
export DOMAIN
export VM_PROJECT_DIR="/home/ubuntu/sre-nginx-ssl"
export NGINX_CONFIG="./nginx/nginx.conf"
envsubst < "${SCRIPT_DIR}/setup-all.sh" > "${SCRIPT_DIR}/setup-all-update.sh"

chmod +x "${SCRIPT_DIR}/setup-all-update.sh" 

# Encode the user data script in base64
base64 -i "${SCRIPT_DIR}/setup-all-update.sh" -o "${SCRIPT_DIR}/setup-all-update_base64.txt"


# Deploy the infrastructure using Terraform
terraform -chdir="${PROJECT_ROOT}" init
terraform -chdir="${PROJECT_ROOT}" fmt
terraform -chdir="${PROJECT_ROOT}" validate
terraform -chdir="${PROJECT_ROOT}" plan -var "region=${REGION}" -var "subdomain_name=${DOMAIN%%.*}" -var "domain_name=${DOMAIN#*.}" -out=plan.out
terraform -chdir="${PROJECT_ROOT}" apply -auto-approve plan.out
terraform -chdir="${PROJECT_ROOT}" output -json > terraform_output.json

# Check if the output file was created successfully
if [ ! -f terraform_output.json ]; then
    echo "Failed to create terraform_output.json. Please check the Terraform output."
    exit 1
fi

sleep 30


INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${INSTANCE_NAME}" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --region ${REGION} \
    --output text)

# Check if an instance ID was found
if [ -z "$INSTANCE_ID" ]; then
    echo "No running instance found with the name ${INSTANCE_NAME} in region ${REGION}."
    exit 1
fi

# Stop the EC2 instance
aws ec2 stop-instances \
    --instance-ids ${INSTANCE_ID} \
    --region ${REGION}

# Wait for the instance to stop
aws ec2 wait instance-stopped \
    --instance-ids ${INSTANCE_ID} \
    --region ${REGION}

# Update the user data script
aws ec2 modify-instance-attribute \
    --instance-id ${INSTANCE_ID} \
    --attribute userData \
    --value file://"${SCRIPT_DIR}/setup-all-update_base64.txt" \
    --region ${REGION}

# Start the EC2 instance
aws ec2 start-instances \
    --instance-ids ${INSTANCE_ID} \
    --region ${REGION}

# Wait for the instance to start
aws ec2 wait instance-running \
    --instance-ids ${INSTANCE_ID} \
    --region ${REGION}

sleep 30

echo "User data updated and instance restarted successfully."

