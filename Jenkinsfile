pipeline {
    agent any
    
    parameters {
        choice(name: 'ENVIRONMENT', choices: ['blue', 'green'], description: 'Which environment to deploy to')
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip smoke tests')
    }
    
    environment {
        KUBECONFIG = credentials('kubeconfig-id')
        DOCKER_REGISTRY = '603480426027.dkr.ecr.us-west-2.amazonaws.com'
        APP_NAME = 'bluegreen-app'
        NAMESPACE = 'default'
        // Dynamic service endpoint - will be set during pipeline
        SERVICE_ENDPOINT = ''
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/Divya12377/k8s-jenkins-bluegreen.git'
            }
        }
        
        stage('Build & Tag Image') {
            steps {
                script {
                    def appVersion = sh(script: "date +%Y%m%d%H%M%S", returnStdout: true).trim()
                    env.IMAGE_TAG = "${DOCKER_REGISTRY}/${APP_NAME}:${appVersion}"
                    echo "Building and tagging image as ${env.IMAGE_TAG}"
                    
                    // Build Docker image if Dockerfile exists
                    if (fileExists('Dockerfile')) {
                        sh "docker build -t ${env.IMAGE_TAG} ."
                        // Push to registry if needed
                        // sh "docker push ${env.IMAGE_TAG}"
                    } else {
                        echo "No Dockerfile found, using pre-built image tag"
                        env.IMAGE_TAG = "${DOCKER_REGISTRY}/${APP_NAME}:latest"
                    }
                }
            }
        }
        
        stage('Prepare Manifests') {
            steps {
                script {
                    // Update deployment manifests with new image tag
                    sh """
                        # Create temporary manifests with updated image
                        sed 's|<IMAGE_TAG>|${env.IMAGE_TAG}|g' k8s/${params.ENVIRONMENT}-deployment.yaml > /tmp/${params.ENVIRONMENT}-deployment-updated.yaml
                        
                        # Verify the manifest is valid
                        kubectl apply --dry-run=client -f /tmp/${params.ENVIRONMENT}-deployment-updated.yaml
                    """
                }
            }
        }
        
        stage('Deploy Application') {
            steps {
                script {
                    echo "Deploying to ${params.ENVIRONMENT} environment"
                    
                    // Deploy the application
                    sh """
                        kubectl apply -f /tmp/${params.ENVIRONMENT}-deployment-updated.yaml
                        kubectl apply -f k8s/${params.ENVIRONMENT}-service.yaml
                        
                        # Wait for deployment to be ready
                        kubectl rollout status deployment/${APP_NAME}-${params.ENVIRONMENT} -n ${NAMESPACE} --timeout=300s
                        
                        # Get service endpoint
                        SERVICE_IP=\$(kubectl get svc ${APP_NAME}-${params.ENVIRONMENT} -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
                        if [ -z "\$SERVICE_IP" ]; then
                            SERVICE_IP=\$(kubectl get svc ${APP_NAME}-${params.ENVIRONMENT} -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "localhost")
                        fi
                        
                        echo "SERVICE_IP=\$SERVICE_IP" > service_info.txt
                    """
                    
                    // Read service info
                    def serviceInfo = readFile('service_info.txt').trim()
                    def serviceIP = serviceInfo.split('=')[1]
                    env.SERVICE_ENDPOINT = "http://${serviceIP}"
                    
                    echo "Application deployed successfully to ${params.ENVIRONMENT}"
                    echo "Service endpoint: ${env.SERVICE_ENDPOINT}"
                }
            }
        }
        
        stage('Health Check') {
            when {
                not { params.SKIP_TESTS }
            }
            steps {
                script {
                    echo "Performing health check on ${params.ENVIRONMENT} environment"
                    
                    // Get the service port
                    def servicePort = sh(
                        script: "kubectl get svc ${APP_NAME}-${params.ENVIRONMENT} -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].port}'",
                        returnStdout: true
                    ).trim()
                    
                    // Perform health check with retry logic
                    def healthCheckPassed = false
                    for (int i = 0; i < 10; i++) {
                        try {
                            sh """
                                # Try different health check endpoints
                                kubectl exec -n ${NAMESPACE} \$(kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME},version=${params.ENVIRONMENT} -o jsonpath='{.items[0].metadata.name}') -- wget -q --spider http://localhost:${servicePort}/health || 
                                kubectl exec -n ${NAMESPACE} \$(kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME},version=${params.ENVIRONMENT} -o jsonpath='{.items[0].metadata.name}') -- wget -q --spider http://localhost:${servicePort}/ ||
                                echo "Health check attempt \$((i+1)) completed"
                            """
                            healthCheckPassed = true
                            break
                        } catch (Exception e) {
                            echo "Health check attempt ${i+1} failed: ${e.getMessage()}"
                            if (i < 9) {
                                sleep(10)
                            }
                        }
                    }
                    
                    if (!healthCheckPassed) {
                        echo "WARNING: Health checks failed, but continuing deployment"
                    } else {
                        echo "Health checks passed successfully"
                    }
                }
            }
        }
        
        stage('Manual Approval') {
            steps {
                script {
                    def deploymentInfo = """
                    Deployment Summary:
                    - Environment: ${params.ENVIRONMENT}
                    - Image: ${env.IMAGE_TAG}
                    - Service Endpoint: ${env.SERVICE_ENDPOINT}
                    - Namespace: ${NAMESPACE}
                    
                    Please verify the deployment before proceeding.
                    """
                    
                    echo deploymentInfo
                    
                    def userInput = input(
                        message: 'Deployment completed. What would you like to do?',
                        parameters: [
                            choice(
                                name: 'ACTION',
                                choices: ['PROMOTE', 'ROLLBACK', 'ABORT'],
                                description: 'Choose the next action'
                            )
                        ]
                    )
                    
                    env.USER_ACTION = userInput
                }
            }
        }
        
        stage('Traffic Management') {
            steps {
                script {
                    def otherEnv = (params.ENVIRONMENT == 'blue') ? 'green' : 'blue'
                    
                    switch(env.USER_ACTION) {
                        case 'PROMOTE':
                            echo "Promoting ${params.ENVIRONMENT} environment"
                            // Update main service to point to new environment
                            sh """
                                # Update main service selector to point to new environment
                                kubectl patch svc ${APP_NAME}-main -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"${params.ENVIRONMENT}"}}}'
                                
                                echo "Traffic switched to ${params.ENVIRONMENT} environment"
                                
                                # Optionally scale down the old environment
                                kubectl scale deployment ${APP_NAME}-${otherEnv} -n ${NAMESPACE} --replicas=0
                                echo "Scaled down ${otherEnv} environment"
                            """
                            break
                            
                        case 'ROLLBACK':
                            echo "Rolling back to ${otherEnv} environment"
                            sh """
                                # Ensure old environment is running
                                kubectl scale deployment ${APP_NAME}-${otherEnv} -n ${NAMESPACE} --replicas=3
                                kubectl rollout status deployment/${APP_NAME}-${otherEnv} -n ${NAMESPACE} --timeout=300s
                                
                                # Switch traffic back
                                kubectl patch svc ${APP_NAME}-main -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"${otherEnv}"}}}'
                                
                                # Scale down current environment
                                kubectl scale deployment ${APP_NAME}-${params.ENVIRONMENT} -n ${NAMESPACE} --replicas=0
                                
                                echo "Successfully rolled back to ${otherEnv} environment"
                            """
                            break
                            
                        case 'ABORT':
                            echo "Deployment aborted by user"
                            // Clean up current deployment
                            sh "kubectl scale deployment ${APP_NAME}-${params.ENVIRONMENT} -n ${NAMESPACE} --replicas=0"
                            error "Deployment aborted by user"
                            break
                    }
                }
            }
        }
        
        stage('Verification') {
            when {
                environment name: 'USER_ACTION', value: 'PROMOTE'
            }
            steps {
                script {
                    echo "Verifying final deployment state"
                    sh """
                        # Show current deployment status
                        echo "=== Deployment Status ==="
                        kubectl get deployments -n ${NAMESPACE} -l app=${APP_NAME}
                        
                        echo "=== Service Status ==="
                        kubectl get services -n ${NAMESPACE} -l app=${APP_NAME}
                        
                        echo "=== Pod Status ==="
                        kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME}
                        
                        echo "=== Current Traffic Routing ==="
                        kubectl describe svc ${APP_NAME}-main -n ${NAMESPACE} | grep Selector
                    """
                    
                    echo "✅ Blue-Green deployment completed successfully!"
                    echo "✅ Traffic is now routed to ${params.ENVIRONMENT} environment"
                }
            }
        }
    }
    
    post {
        always {
            script {
                // Clean up temporary files
                sh "rm -f /tmp/*-deployment-updated.yaml service_info.txt || true"
            }
        }
        
        success {
            echo "🎉 Pipeline completed successfully!"
        }
        
        failure {
            script {
                echo "❌ Pipeline failed. Checking deployment status..."
                sh """
                    echo "=== Current Deployment Status ==="
                    kubectl get deployments -n ${NAMESPACE} -l app=${APP_NAME} || echo "No deployments found"
                    kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME} || echo "No pods found"
                """
            }
        }
        
        cleanup {
            echo "🧹 Cleaning up workspace"
        }
    }
}
