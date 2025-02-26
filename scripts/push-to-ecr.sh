#!/bin/bash 

# Get into the terraform directory and get the ECR URL 
cd terraform
ECR_REPO=$(terraform output -raw ecr_repository_url)
cd ..

# Authenticate Docker to the ECR registry
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $ECR_REPO

cd ../spa-playground

docker build -t $ECR_REPO:frontend ./frontend 
docker build -t $ECR_REPO:backend ./backend

docker push $ECR_REPO:frontend
docker push $ECR_REPO:backend

