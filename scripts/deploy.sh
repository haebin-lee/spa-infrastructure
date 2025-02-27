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

# AWS ECR Authentication
AWS_REGION=${AWS_REGION}
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO

echo "Pulling latest images..."
docker pull $ECR_REPO:frontend
docker pull $ECR_REPO:backend

echo "Starting containers with docker-compose..."
docker-compose up -d

echo "Deployment completed successfully!"