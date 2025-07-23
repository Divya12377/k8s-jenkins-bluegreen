pipeline {
  agent any
  parameters {
    choice(name: 'DEPLOY_COLOR', choices: ['blue', 'green'], description: 'Which environment to deploy')
  }
  environment {
    AWS_ECR = '603480426027.dkr.ecr.us-west-2.amazonaws.com'
    IMAGE_NAME = 'nodejs-app'
    K8S_NAMESPACE = 'default'
    SERVICE_NAME = 'blue-green'
    DEPLOYMENT_TEMPLATE = "k8s-manifests/app/${params.DEPLOY_COLOR}-deployment.yaml"
    IMAGE = ''
    // Add tool paths
    AWS_CLI = '/usr/local/bin/aws'
    DOCKER = '/usr/bin/docker'
    KUBECTL = '/usr/local/bin/kubectl'
  }
  stages {
    stage('Verify Tools') {
      steps {
        script {
          sh '''
            echo "Checking for required tools..."
            which aws || echo "AWS CLI not found in PATH"
            which docker || echo "Docker not found in PATH"
            which kubectl || echo "kubectl not found in PATH"
            
            # Try common installation locations
            find /usr -name "aws" 2>/dev/null || echo "AWS CLI not found in /usr"
            find /usr -name "docker" 2>/dev/null || echo "Docker not found in /usr"
            find /usr -name "kubectl" 2>/dev/null || echo "kubectl not found in /usr"
          '''
        }
      }
    }
    stage('Checkout') {
      steps {
        git branch: 'main', url: 'https://github.com/Divya12377/k8s-jenkins-bluegreen.git'
      }
    }
    stage('Build & Push Docker Image') {
      steps {
        script {
          def imageTag = "${AWS_ECR}/${IMAGE_NAME}:${BUILD_NUMBER}"
          sh """
            ${AWS_CLI} ecr get-login-password --region us-west-2 | ${DOCKER} login --username AWS --password-stdin ${AWS_ECR}
            ${DOCKER} build -t ${imageTag} .
            ${DOCKER} push ${imageTag}
          """
          env.IMAGE = imageTag
        }
      }
    }
    stage('Deploy to Kubernetes') {
      steps {
        script {
          sh """
            sed 's|<IMAGE>|${env.IMAGE}|g' ${DEPLOYMENT_TEMPLATE} | ${KUBECTL} apply -n ${K8S_NAMESPACE} -f -
            ${KUBECTL} scale deployment nodejs-app-${params.DEPLOY_COLOR} -n ${K8S_NAMESPACE} --replicas=3
          """
        }
      }
    }
    stage('Health Check') {
      steps {
        script {
          def elb = "http://aaa72dc9d10da4d1cbc664ee91114d82-715267764.us-west-2.elb.amazonaws.com"
          def status = sh(script: """
            for i in {1..10}; do
              curl -sf ${elb}/health && exit 0 || sleep 5
            done
            exit 1
          """, returnStatus: true)
          if (status != 0) {
            error "Health check failed! Triggering rollback..."
          }
        }
      }
    }
    stage('Switch Traffic') {
      steps {
        script {
          sh """
            ${KUBECTL} patch svc ${SERVICE_NAME} -n ${K8S_NAMESPACE} \
              -p '{"spec": {"selector": {"app": "nodejs-app", "version": "${params.DEPLOY_COLOR}"}}}'
          """
        }
      }
    }
    stage('Scale Down Old') {
      steps {
        script {
          def OLD = (params.DEPLOY_COLOR == 'blue') ? 'green' : 'blue'
          sh "${KUBECTL} scale deployment nodejs-app-${OLD} -n ${K8S_NAMESPACE} --replicas=0"
        }
      }
    }
  }
  post {
    failure {
      script {
        def OLD = (params.DEPLOY_COLOR == 'blue') ? 'green' : 'blue'
        def rollbackTemplate = "k8s-manifests/app/${OLD}-deployment.yaml"
        echo "Rolling back to previous version: ${OLD}"
        def latestStableImage = sh(script: """
          ${KUBECTL} get deployment nodejs-app-${OLD} -n ${K8S_NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo '${AWS_ECR}/${IMAGE_NAME}:latest'
        """, returnStdout: true).trim()
        
        sh """
          sed 's|<IMAGE>|${latestStableImage}|g' ${rollbackTemplate} | ${KUBECTL} apply -n ${K8S_NAMESPACE} -f -
          ${KUBECTL} scale deployment nodejs-app-${OLD} -n ${K8S_NAMESPACE} --replicas=3
          ${KUBECTL} patch svc ${SERVICE_NAME} -n ${K8S_NAMESPACE} \
            -p '{"spec": {"selector": {"app": "nodejs-app", "version": "${OLD}"}}}'
          ${KUBECTL} scale deployment nodejs-app-${params.DEPLOY_COLOR} -n ${K8S_NAMESPACE} --replicas=0
        """
      }
    }
  }
}
