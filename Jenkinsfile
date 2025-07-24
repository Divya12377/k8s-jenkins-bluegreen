pipeline {
    agent any
    
    parameters {
        choice(name: 'ENVIRONMENT', choices: ['blue', 'green'], description: 'Which environment to deploy to')
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip smoke tests')
    }
    
    environment {
        APP_NAME = 'nodejs-app'
        NAMESPACE = 'default'
        IMAGE_TAG = ''
        AWS_ACCOUNT_ID = '603480426027'
        AWS_REGION = 'us-west-2'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        DOMAIN = 'aaa72dc9d10da4d1cbc664ee91114d82-715267764.us-west-2.elb.amazonaws.com'
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "🚀 Checking out code from repository"
                checkout scm
            }
        }
        
        stage('Verify Prerequisites') {
            steps {
                script {
                    echo "🔍 Verifying required tools..."
                    
                    // Install kubectl if missing
                    if (sh(script: "which kubectl", returnStatus: true) != 0) {
                        echo "Installing kubectl..."
                        sh """
                            curl -LO "https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                            install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
                        """
                    }
                    
                    // Verify other tools
                    ['docker', 'aws'].each { tool ->
                        if (sh(script: "which ${tool}", returnStatus: true) != 0) {
                            error("❌ ${tool} not found! Please install it on Jenkins workers.")
                        }
                    }
                    
                    // Verify cluster access
                    sh "kubectl cluster-info"
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    def timestamp = new Date().format('yyyyMMddHHmmss')
                    env.IMAGE_TAG = "${ECR_REGISTRY}/${APP_NAME}:${timestamp}-${params.ENVIRONMENT}"
                    
                    echo "🐳 Building Docker image: ${env.IMAGE_TAG}"
                    docker.build("${env.IMAGE_TAG}", "./app")
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    echo "📦 Pushing image to ECR"
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    """
                    docker.withRegistry("https://${ECR_REGISTRY}") {
                        docker.image("${env.IMAGE_TAG}").push()
                    }
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    echo "⚙️ Updating ${params.ENVIRONMENT} deployment"
                    
                    // Update deployment manifest
                    sh """
                        sed -i "s|image:.*|image: ${env.IMAGE_TAG}|g" k8s-manifests/app/${params.ENVIRONMENT}-deployment.yaml
                        kubectl apply -f k8s-manifests/app/${params.ENVIRONMENT}-deployment.yaml
                    """
                    
                    // Wait for rollout
                    timeout(time: 2, unit: 'MINUTES') {
                        sh """
                            kubectl rollout status deployment/${APP_NAME}-${params.ENVIRONMENT} -n ${NAMESPACE}
                        """
                    }
                }
            }
        }
        
        stage('Verify Deployment') {
            when {
                expression { params.SKIP_TESTS != true }
            }
            steps {
                script {
                    echo "🧪 Running health checks..."
                    def pod = sh(
                        script: "kubectl get pod -l app=${APP_NAME},version=${params.ENVIRONMENT} -o jsonpath='{.items[0].metadata.name}'",
                        returnStdout: true
                    ).trim()
                    
                    sh """
                        kubectl exec ${pod} -- curl -sSf http://localhost:3000/health || {
                            echo "❌ Health check failed"
                            exit 1
                        }
                    """
                }
            }
        }
        
        stage('Switch Traffic') {
            steps {
                script {
                    echo "🔄 Switching traffic to ${params.ENVIRONMENT}"
                    
                    // Get current active service
                    def currentService = sh(
                        script: "kubectl get ingress nodejs-app-ingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}'",
                        returnStdout: true
                    ).trim()
                    
                    if (currentService == "nodejs-app-${params.ENVIRONMENT}") {
                        echo "⚠️ Traffic already pointing to ${params.ENVIRONMENT}"
                    } else {
                        // Update ingress
                        sh """
                            kubectl patch ingress nodejs-app-ingress \
                              -p '{"spec":{"rules":[{"host":"${DOMAIN}","http":{"paths":[{"backend":{"service":{"name":"nodejs-app-${params.ENVIRONMENT}"}}}]}}]}'
                        """
                        
                        echo "✅ Traffic switched from ${currentService} to nodejs-app-${params.ENVIRONMENT}"
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "🏁 Pipeline execution completed"
            // Basic cleanup without cleanWs plugin
            deleteDir()
        }
        success {
            echo "🎉 Successfully deployed to ${params.ENVIRONMENT} environment!"
        }
        failure {
            echo "❌ Pipeline failed - check logs for details"
        }
    }
}
