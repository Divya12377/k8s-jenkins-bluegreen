#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

# Source environment variables
source .env

print_header "Complete EKS + Jenkins Blue-Green Setup"

# Update manifests with actual values
print_status "Updating Kubernetes manifests with actual values..."
sed -i.bak "s/AWS_ACCOUNT_PLACEHOLDER/$AWS_ACCOUNT/g" k8s-manifests/app/blue-deployment.yaml
sed -i.bak "s/AWS_REGION_PLACEHOLDER/$AWS_REGION/g" k8s-manifests/app/blue-deployment.yaml
sed -i.bak "s/AWS_ACCOUNT_PLACEHOLDER/$AWS_ACCOUNT/g" k8s-manifests/app/green-deployment.yaml
sed -i.bak "s/AWS_REGION_PLACEHOLDER/$AWS_REGION/g" k8s-manifests/app/green-deployment.yaml

# Step 1: Setup EKS
print_header "Step 1: Setting up EKS Cluster"
if ! kubectl cluster-info &>/dev/null; then
    ./scripts/setup-eks.sh
else
    print_status "EKS cluster already exists and is accessible"
fi

# Step 2: Setup ECR and build images
print_header "Step 2: Setting up ECR and building images"
./scripts/setup-ecr.sh

# Step 3: Install ALB Controller
print_header "Step 3: Installing ALB Controller"
print_status "Adding EKS Helm repository..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

print_status "Installing AWS Load Balancer Controller..."
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=$AWS_REGION \
    --set vpcId=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${CLUSTER_NAME}-vpc" --query 'Vpcs[0].VpcId' --output text) \
    --wait

# Step 3.1: Install EBS CSI Driver
print_header "Step 3.1: Installing EBS CSI Driver"
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/ecr/?ref=release-1.28"

# Step 4: Deploy application
print_header "Step 4: Deploying application"
print_status "Deploying blue-green application..."
kubectl apply -f k8s-manifests/app/blue-deployment.yaml
kubectl apply -f k8s-manifests/app/green-deployment.yaml
kubectl apply -f k8s-manifests/app/service.yaml
kubectl apply -f k8s-manifests/app/ingress.yaml

print_status "Waiting for blue deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/nodejs-app-blue

# Step 5: Setup Jenkins
print_header "Step 5: Setting up Jenkins"
./scripts/setup-jenkins.sh

# Step 6: Final verification
print_header "Step 6: Final verification"
print_status "Verifying deployments..."
kubectl get deployments
kubectl get services
kubectl get ingress

APP_URL=$(kubectl get ingress nodejs-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
JENKINS_URL=$(kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

print_header "Setup Complete!"
echo ""
print_status "Application URL: http://$APP_URL"
print_status "Jenkins URL: http://$JENKINS_URL"
print_status "Jenkins Username: admin"
print_status "Jenkins Password: $JENKINS_ADMIN_PASSWORD"
echo ""
print_status "To switch between environments:"
print_status "  ./scripts/blue-green-switch.sh switch green"
print_status "  ./scripts/blue-green-switch.sh switch blue"
print_status "  ./scripts/blue-green-switch.sh status"
echo ""
print_status "To test the setup:"
print_status "  curl http://$APP_URL/"
print_status "  curl http://$APP_URL/health"
print_status "  curl http://$APP_URL/version"
echo ""
print_warning "Save your Jenkins password: $JENKINS_ADMIN_PASSWORD"
