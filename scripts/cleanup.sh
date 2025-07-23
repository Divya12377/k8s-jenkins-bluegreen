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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Source environment variables
source .env

print_warning "This will delete all resources created by this project!"
print_warning "Cluster: $CLUSTER_NAME"
print_warning "Region: $AWS_REGION"
print_warning "ECR Repository: $ECR_REPO_NAME"

read -p "Are you sure you want to proceed? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    print_status "Cleanup cancelled"
    exit 0
fi

# Delete Kubernetes resources
print_status "Deleting Kubernetes resources..."
kubectl delete ingress nodejs-app --ignore-not-found=true
kubectl delete service nodejs-app-blue nodejs-app-green --ignore-not-found=true
kubectl delete deployment nodejs-app-blue nodejs-app-green --ignore-not-found=true

# Delete Jenkins
print_status "Deleting Jenkins..."
helm uninstall jenkins -n jenkins --ignore-not-found
kubectl delete namespace jenkins --ignore-not-found=true

# Delete ALB Controller
print_status "Deleting ALB Controller..."
helm uninstall aws-load-balancer-controller -n kube-system --ignore-not-found

# Delete EKS cluster and infrastructure using Terraform
print_status "Deleting EKS cluster and infrastructure..."
cd terraform
terraform destroy -var="cluster_name=$CLUSTER_NAME" -var="region=$AWS_REGION" -auto-approve
cd ..

# Delete ECR images
print_status "Deleting ECR images..."
aws ecr batch-delete-image \
    --repository-name $ECR_REPO_NAME \
    --image-ids imageTag=blue imageTag=green \
    --region $AWS_REGION \
    --no-cli-pager || true

print_status "Cleanup completed!"
print_warning "Please verify in AWS Console that all resources have been deleted"

