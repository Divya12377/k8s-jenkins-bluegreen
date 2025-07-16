# k8s-jenkins-bluegreen
# Kubernetes Jenkins Blue-Green Deployment

This project demonstrates a complete CI/CD pipeline with blue-green deployment using:
- AWS EKS (Kubernetes cluster)
- Jenkins (CI/CD tool)
- Node.js sample application
- Docker containers
- Kubernetes manifests

## Quick Start
1. Prerequisites: AWS CLI, kubectl, eksctl, Docker
2. Setup: Run `./scripts/setup-complete.sh`
3. Configure Jenkins: Access Jenkins UI and configure pipeline
4. Deploy: Push code changes to trigger blue-green deployment
