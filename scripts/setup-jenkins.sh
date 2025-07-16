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

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."

# Generate Jenkins admin password if not set
if [ -z "$JENKINS_ADMIN_PASSWORD" ]; then
    JENKINS_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
    print_status "Generated Jenkins admin password: $JENKINS_ADMIN_PASSWORD"
fi

print_status "Setting up Jenkins with Helm..."

# Create namespace
NAMESPACE_FILE="$PROJECT_ROOT/k8s-manifests/jenkins/namespace.yaml"
if [ ! -f "$NAMESPACE_FILE" ]; then
    print_error "Namespace file not found at $NAMESPACE_FILE"
    exit 1
fi
kubectl apply -f "$NAMESPACE_FILE"

# Create StorageClass with immediate binding
print_status "Creating StorageClass for immediate volume binding"
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: jenkins-immediate
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
volumeBindingMode: Immediate
reclaimPolicy: Delete
EOF

# Add Jenkins Helm repository
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Update values file with actual password
VALUES_FILE="$PROJECT_ROOT/k8s-manifests/jenkins/values.yaml"
if [ ! -f "$VALUES_FILE" ]; then
    print_error "Values file not found at $VALUES_FILE"
    exit 1
fi

sed "s/JENKINS_ADMIN_PASSWORD_PLACEHOLDER/$JENKINS_ADMIN_PASSWORD/g" \
    "$VALUES_FILE" > /tmp/jenkins-values.yaml

# Update storageClass in values
sed -i 's/storageClass:.*/storageClass: jenkins-immediate/' /tmp/jenkins-values.yaml

# Install Jenkins
print_status "Installing Jenkins..."
helm upgrade --install jenkins jenkins/jenkins \
  -n jenkins \
  -f /tmp/jenkins-values.yaml \
  --wait \
  --timeout 15m  # Increased timeout

# Wait for Jenkins to be ready
print_status "Waiting for Jenkins to be ready..."
kubectl wait --for=condition=available deployment/jenkins -n jenkins --timeout=600s

# Get Jenkins URL
print_status "Getting Jenkins URL..."
sleep 30  # Wait for LoadBalancer provisioning
JENKINS_URL=$(kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || true)

if [ -z "$JENKINS_URL" ]; then
    print_error "Failed to get Jenkins URL"
    print_status "Trying alternative method..."
    JENKINS_URL=$(kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
fi

print_status "Jenkins setup complete!"
print_status "Jenkins URL: http://$JENKINS_URL"
print_status "Admin Username: admin"
print_status "Admin Password: $JENKINS_ADMIN_PASSWORD"

# Clean up temp file
rm /tmp/jenkins-values.yaml
