# SPA Infrastructure

This repository contains infrastructure code for a Single Page Application (SPA). It implements automated build, test, and deployment processes using GitHub Actions workflows. The application code is [here](https://github.com/haebin-lee/spa-source).

For a detailed explanation of this infrastructure setup, check out my [blog post](https://medium.com/@hblee8080/step-by-step-deploy-the-spa-application-by-building-ci-cd-pipeline-with-github-actions-bed436ee9c2b).

## Repository Structure

```
spa-infrastructure/
├── .github/
│   └── workflows/
│       ├── mock-test.yml      # Daily automatic and manual build/test workflow
│       └── qa-deploy.yml      # QA environment deployment workflow
├── scripts/
│   ├── deploy.sh              # Production/QA deployment script
│   ├── docker-compose.yml     # Docker Compose configuration for EC2
│   ├── ec2-creation.sh        # Temporary EC2 instance creation script
│   ├── ec2-deletion.sh        # Temporary EC2 instance deletion script
│   ├── ec2-deploy.sh          # Temporary EC2 instance deploy script
│   ├── push-to-ecr.sh         # ECR image push script
│   ├── smoke-tests.sh         # Basic functionality test script
│   └── user-data.sh           # EC2 user data script
├── .gitignore                 # Git ignore file
└── terraform.tfstate          # Terraform state file
```

## Workflow Description

### Build, Deploy and Mock Test (`mock-test.yml`)

This workflow runs daily at 00:00 (midnight) automatically and can also be triggered manually. It performs the following steps:

1. Checks out the infrastructure repository
2. Checks out the source code repository (spa-source)
3. Configures AWS credentials
4. Builds Docker images for frontend and backend
5. Automatically creates a temporary EC2 instance for smoke testing
6. Deploys the application to the temporary instance
7. Runs smoke tests to verify basic functionality
8. On success, pushes Docker images to Amazon ECR
9. Cleans up the temporary EC2 instance (even if the tests fail)

### QA Deployment (`qa-deploy.yml`)

This workflow runs automatically after a successful completion of the "Build, Deploy and Mock Test" workflow or can be triggered manually. It performs the following steps:

1. Checks out the infrastructure repository
2. Configures AWS credentials
3. Copies deployment files to the pre-configured QA EC2 instance
4. Deploys the latest images from ECR to the QA environment

## Setup Requirements

To use this infrastructure, you need to configure the following GitHub secrets:

- AWS credentials: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION`
- ECR repository: `ECR_REPO`
- EC2 access: `EC2_HOST`, `EC2_USERNAME`, `EC2_SSH_KEY`, `EC2_SSH_KEY_NAME`
- Database configuration: `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_PORT`, `DB_SG_ID`
- Repository access: `GH_PAT` (GitHub Personal Access Token)
