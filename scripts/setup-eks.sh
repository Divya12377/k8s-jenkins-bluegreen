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

print_status "Setting up EKS cluster using Terraform..."

# Initialize Terraform
cd terraform
terraform init

# Plan the infrastructure
terraform plan -var="cluster_name=$CLUSTER_NAME" -var="region=$AWS_REGION"

# Apply the infrastructure
terraform apply -var="cluster_name=$CLUSTER_NAME" -var="region=$AWS_REGION" -auto-approve

cd ..

# Update kubeconfig
print_status "Updating kubeconfig..."
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Verify cluster
print_status "Verifying cluster..."
kubectl cluster-info
kubectl get nodes

print_status "EKS cluster $CLUSTER_NAME created successfully!"
