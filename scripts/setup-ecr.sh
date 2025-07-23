#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Source environment variables
source .env

print_status "Setting up ECR and building initial images..."

# Login to ECR
print_status "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push blue image
print_status "Building and pushing blue image..."
cd app
docker build -t $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/nodejs-app:blue .
docker push $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/nodejs-app:blue

# Build and push green image (initially same as blue)
print_status "Building and pushing green image..."
docker build -t $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/nodejs-app:green .
docker push $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/nodejs-app:green

cd ..

print_status "ECR setup complete!"
