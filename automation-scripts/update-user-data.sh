#!/bin/bash

# variables
REGION="us-east-1"
INSTANCE_NAME="nginxApp"
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

# Encode the user data script in base64
base64 -i ./setup-all.sh -o ./setup-all_base64.txt

# Update the user data script
aws ec2 modify-instance-attribute \
    --instance-id ${INSTANCE_ID} \
    --attribute userData \
    --value file://setup-all_base64.txt \
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

