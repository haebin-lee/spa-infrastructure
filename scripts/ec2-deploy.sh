#!/bin/bash

# Stop on errors
set -e

# Create .env file for docker-compose
cat > .env << EOF
ECR_REPO=local
DB_HOST=${DB_HOST}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=${DB_NAME}
DB_PORT=${DB_PORT}
EOF

docker load < frontend.tar
docker load < backend.tar
docker-compose up -d

sleep 30
echo "Deployment completed successfully!"