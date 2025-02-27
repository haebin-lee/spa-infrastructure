#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration - update these values
AWS_REGION="us-east-1"
INSTANCE_TYPE="t2.micro"
AMI_ID="ami-05b10e08d247fb927" 
KEY_NAME="ec2-key" 
SG_NAME="temp-test-sg-$(date +%s)"
TEST_NAME="smoke-test-$(date +%s)"
USER_DATA_PATH="./user-data.sh"

# Create a security group
echo "Creating temporary security group..."
SG_ID=$(aws ec2 create-security-group \
  --group-name "$SG_NAME" \
  --description "Temporary security group for smoke testing" \
  --region $AWS_REGION \
  --output text \
  --query 'GroupId')

echo "Security group created: $SG_ID"

# Add necessary inbound rules
echo "Configuring security group rules..."
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $AWS_REGION > /dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $AWS_REGION > /dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 3000 --cidr 0.0.0.0/0 --region $AWS_REGION > /dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region $AWS_REGION > /dev/null

# Encode user data script
# With these lines:
echo "Using user data script from: $USER_DATA_PATH"
USER_DATA_PARAM="--user-data file://$USER_DATA_PATH"

# Launch EC2 instance
echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  $USER_DATA_PARAM \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TEST_NAME},{Key=Environment,Value=SmokeTest}]" \
  --region $AWS_REGION \
  --output text \
  --query 'Instances[0].InstanceId')

echo "Instance launched: $INSTANCE_ID"

# Wait for instance to be running
echo "Waiting for instance to reach running state..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text \
  --region $AWS_REGION)

echo "Instance is running with public IP: $PUBLIC_IP"
echo "Waiting for instance initialization (user data script)..."
echo "This may take a few minutes..."
sleep 120  # Allow time for user-data script to execute

echo "---START---"
echo "Temporary EC2 instance is ready for testing"
echo "public_ip=$PUBLIC_IP"
echo "instance_id=$INSTANCE_ID"
echo "sg_id=$SG_ID"
echo "---END---"
