#!/bin/bash

# Stop on errors
set -e

log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

# Check required environment variables
required_vars=(
  "ECR_REPO"
  "AWS_ACCESS_KEY_ID"
  "AWS_SECRET_ACCESS_KEY"
  "AWS_REGION"
  "DB_HOST"
  "DB_USER"
  "DB_PASSWORD"
  "DB_NAME"
  "DB_PORT"
)

for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    log "ERROR: Required environment variable $var is not set"
    exit 1
  fi
done

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
sudo mkdir -p /root/.aws /home/ec2-user/.aws

sudo chown ec2-user:ec2-user /home/ec2-user/.aws

# Pass AWS credentials to instance
cat > /home/ec2-user/.aws/credentials << AWSCREDS
[default]
aws_access_key_id=${AWS_ACCESS_KEY_ID}
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
aws_session_token=${AWS_SESSION_TOKEN}
AWSCREDS
sudo cp /home/ec2-user/.aws/credentials /root/.aws/credentials

# Set up AWS region configuration
cat > /home/ec2-user/.aws/config << AWSCONFIG
[default]
region=${AWS_REGION}
output=json
AWSCONFIG
sudo cp /home/ec2-user/.aws/config /root/.aws/config

# AWS ECR Authentication
AWS_REGION=${AWS_REGION}
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO

# Check for existing containers and clean up
log "Checking for existing deployment..."
if docker-compose ps &>/dev/null; then
  log "Stopping existing containers..."
  docker-compose down || log "Warning: Failed to stop existing containers"
fi

echo "Pulling latest images..."
docker pull $ECR_REPO:frontend
docker pull $ECR_REPO:backend

echo "Starting containers with docker-compose..."
docker-compose up -d

sleep 30
echo "Deployment completed successfully!"