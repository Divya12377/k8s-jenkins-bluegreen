pipeline {
    agent any
    
    parameters {
        choice(name: 'ENVIRONMENT', choices: ['blue', 'green'], description: 'Which environment to deploy to')
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip smoke tests')
    }
    
    environment {
        APP_NAME = 'bluegreen-app'
        NAMESPACE = 'default'
        IMAGE_TAG = ''
        AWS_ACCOUNT_ID = '603480426027'
        AWS_REGION = 'us-west-2'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "Checking out code from repository"
                git branch: 'main', url: 'https://github.com/Divya12377/k8s-jenkins-bluegreen.git'
            }
        }
        
        stage('Check Prerequisites') {
            steps {
                script {
                    echo "=== Checking for required tools ==="
                    def missingTools = []
                    
                    // Check tools with proper error handling
                    ['kubectl', 'docker', 'aws'].each { tool ->
                        if (sh(script: "which ${tool}", returnStatus: true) != 0) {
                            missingTools.add(tool)
                        }
                    }
                    
                    if (missingTools) {
                        error("❌ Missing critical tools: ${missingTools.join(', ')}. Pipeline aborted.")
                    } else {
                        echo "✅ All tools are available"
                        
                        // Verify AWS and ECR access
                        sh """
                            aws sts get-caller-identity
                            aws ecr get-login-password | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        """
                    }
                }
            }
        }
        
        stage('Generate Image Tag') {
            steps {
                script {
                    def timestamp = new Date().format('yyyyMMddHHmmss')
                    env.IMAGE_TAG = "${ECR_REGISTRY}/${APP_NAME}:${timestamp}"
                    echo "Generated image tag: ${env.IMAGE_TAG}"
                }
            }
        }
        
        stage('Build & Push Docker Image') {
            steps {
                script {
                    docker.build("${env.IMAGE_TAG}", "./app")
                    docker.withRegistry("https://${ECR_REGISTRY}", 'ecr-credentials') {
                        docker.image("${env.IMAGE_TAG}").push()
                    }
                }
            }
        }
        
        stage('Prepare Deployment') {
            steps {
                script {
                    def manifestFile = "k8s-manifests/${params.ENVIRONMENT}-deployment.yaml"
                    if (!fileExists(manifestFile)) {
                        error("❌ Manifest file ${manifestFile} not found!")
                    }
                    
                    // Update image tag in manifest (simplified example)
                    sh """
                        sed -i "s|image:.*|image: ${env.IMAGE_TAG}|g" ${manifestFile}
                    """
                    echo "Updated ${manifestFile} with image: ${env.IMAGE_TAG}"
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    echo "🚀 Deploying to ${params.ENVIRONMENT} environment"
                    
                    sh """
                        kubectl apply -f k8s-manifests/${params.ENVIRONMENT}-deployment.yaml
                        kubectl apply -f k8s-manifests/${params.ENVIRONMENT}-service.yaml
                    """
                    
                    // Verify deployment
                    def rolloutStatus = sh(
                        script: "kubectl rollout status deployment/${APP_NAME}-${params.ENVIRONMENT} -n ${NAMESPACE} --timeout=60s",
                        returnStatus: true
                    )
                    
                    if (rolloutStatus != 0) {
                        error("❌ Deployment failed!")
                    }
                }
            }
        }
        
        stage('Health Check') {
            when {
                expression { params.SKIP_TESTS != true }
            }
            steps {
                script {
                    echo "🏥 Performing health check on ${params.ENVIRONMENT} environment"
                    def serviceUrl = sh(
                        script: "kubectl get svc ${APP_NAME}-${params.ENVIRONMENT} -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'",
                        returnStdout: true
                    ).trim()
                    
                    // Simple curl test (replace with your actual health check)
                    sh """
                        curl -sSf http://${serviceUrl}:8080/healthz || {
                            echo "❌ Health check failed"
                            exit 1
                        }
                    """
                    echo "✅ Health check passed"
                }
            }
        }
        
        stage('Traffic Switch') {
            steps {
                script {
                    def otherEnv = (params.ENVIRONMENT == 'blue') ? 'green' : 'blue'
                    
                    // Scale down the inactive environment
                    sh """
                        kubectl scale deployment/${APP_NAME}-${otherEnv} -n ${NAMESPACE} --replicas=0
                    """
                    echo "Traffic switched to ${params.ENVIRONMENT} (${otherEnv} scaled down)"
                }
            }
        }
        
        stage('Cleanup') {
            steps {
                script {
                    echo "🧹 Cleaning up temporary files"
                    sh "find . -name '*.tmp' -delete"
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🧹 Pipeline cleanup completed"
                // Send notification (example)
                emailext (
                    subject: "Pipeline ${currentBuild.result ?: 'SUCCESS'} - ${env.JOB_NAME}",
                    body: "View build: ${env.BUILD_URL}",
                    to: 'your-email@example.com'
                )
            }
        }
        
        success {
            echo "🎉 Pipeline succeeded!"
        }
        
        failure {
            echo "❌ Pipeline failed!"
            // Optional rollback logic could be added here
        }
    }
}
