#!/bin/bash

# Stop on errors
set -e

# Create .env file for docker-compose
cat > .env << EOF
ECR_REPO=${ECR_REPO}
DB_HOST=${DB_HOST}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=${DB_NAME}
DB_PORT=${DB_PORT}
EOF


# Setup AWS credentials directories
mkdir -p /root/.aws /home/ec2-user/.aws

chmod 600 /home/ec2-user/.aws/credentials /root/.aws/credentials

# Pass AWS credentials to instance
cat > /home/ec2-user/.aws/credentials << AWSCREDS
[default]
aws_access_key_id=${AWS_ACCESS_KEY_ID}
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
aws_session_token=${AWS_SESSION_TOKEN}
AWSCREDS

# Set up AWS region configuration
cat > /home/ec2-user/.aws/config << AWSCONFIG
[default]
region=${AWS_REGION}
output=json
AWSCONFIG

# Copy config to root user
cp /home/ec2-user/.aws/config /root/.aws/config

# AWS ECR Authentication
AWS_REGION=${AWS_REGION}
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO

echo "Pulling latest images..."
docker pull $ECR_REPO:frontend
docker pull $ECR_REPO:backend

echo "Starting containers with docker-compose..."
docker-compose up -d

sleep 60
echo "Deployment completed successfully!"