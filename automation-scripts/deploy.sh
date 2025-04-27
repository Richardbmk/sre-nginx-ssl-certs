#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"

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
KEY_NAME="${5}"
SSH_KEY_PATH="$HOME/.ssh/${KEY_NAME}.pem"

if [ -z "$REGION" ] || [ -z "$INSTANCE_NAME" ] || [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "Usage: $0 <region> <instance_name> <domain> <email> [ssh_key_path]"
    echo "Example: $0 us-east-1 nginx-app tweetsapp.ricardoboriba.net user@example.com sre-keys"
    exit 1
fi

# Validate SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "SSH key not found at: $SSH_KEY_PATH"
    exit 1
fi

echo "Using SSH key: $SSH_KEY_PATH"

# Deploy the infrastructure using Terraform
echo "Deploying infrastructure with Terraform..."
terraform -chdir="${PROJECT_ROOT}" init
terraform -chdir="${PROJECT_ROOT}" fmt
terraform -chdir="${PROJECT_ROOT}" validate
terraform -chdir="${PROJECT_ROOT}" plan -var "region=${REGION}" -var "subdomain_name=${DOMAIN%%.*}" -var "domain_name=${DOMAIN#*.}" -var "key_name=${KEY_NAME}" -var "ec2_name=${INSTANCE_NAME}" -out=plan.out
terraform -chdir="${PROJECT_ROOT}" apply -auto-approve plan.out
terraform -chdir="${PROJECT_ROOT}" output -json > terraform_output.json

# Check if the output file was created successfully
if [ ! -f terraform_output.json ]; then
    echo "Failed to create terraform_output.json. Please check the Terraform output."
    exit 1
fi

# Get the instance IP address
echo "Getting EC2 instance information..."
INSTANCE_IP=$(terraform -chdir="${PROJECT_ROOT}" output -raw instance_public_ip)
echo "EC2 instance IP address: $INSTANCE_IP"


# Wait for SSH to be available
echo "Waiting for SSH to be available on the EC2 instance..."
for i in {1..6}; do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$SSH_KEY_PATH" ubuntu@${INSTANCE_IP} echo "SSH ready" &>/dev/null; then
        echo "SSH is available on the EC2 instance."
        break
    else
        echo "Waiting for SSH to be available on the EC2 instance..."
        sleep 10
    fi

    if [ $i -eq 6 ]; then
        echo "SSH is not available on the EC2 instance after multiple attempts."
        exit 1
    fi
done


# Set environment variables for Ansible
echo "Setting up Ansible environment..."
cd "${ANSIBLE_DIR}"
export REGION="${REGION}"
export EC2_NAME="${INSTANCE_NAME}"

# Check Ansible inventory
echo "Checking Ansible inventory..."
ansible-inventory -i "${ANSIBLE_DIR}/inventory/aws_ec2.yml" --list


# Run Ansible playbooks
echo "Configuring EC2 instance with Ansible..."
ansible-playbook -i "${ANSIBLE_DIR}/inventory/aws_ec2.yml" "${ANSIBLE_DIR}/playbooks/site.yml" \
  -e "domain_name=${DOMAIN}" \
  -e "email_address=${EMAIL}"

