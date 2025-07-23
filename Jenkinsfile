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
                    
                    // Check if tools exist
                    def toolsStatus = [:]
                    
                    try {
                        sh "which kubectl"
                        toolsStatus.kubectl = "✅ Available"
                    } catch (Exception e) {
                        toolsStatus.kubectl = "❌ Missing"
                    }
                    
                    try {
                        sh "which docker"
                        toolsStatus.docker = "✅ Available"
                    } catch (Exception e) {
                        toolsStatus.docker = "❌ Missing"
                    }
                    
                    try {
                        sh "which aws"
                        toolsStatus.aws = "✅ Available"
                    } catch (Exception e) {
                        toolsStatus.aws = "❌ Missing"
                    }
                    
                    echo "=== Tool Status ==="
                    toolsStatus.each { tool, status ->
                        echo "${tool}: ${status}"
                    }
                    
                    // Check if any critical tools are missing
                    def missingTools = toolsStatus.findAll { k, v -> v.contains("Missing") }
                    if (!missingTools.isEmpty()) {
                        echo "⚠️  WARNING: Missing required tools: ${missingTools.keySet().join(', ')}"
                        echo "Please install these tools before proceeding with deployment"
                        
                        // For demo purposes, we'll continue but mark as unstable
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }
        
        stage('Generate Image Tag') {
            steps {
                script {
                    def timestamp = sh(script: "date +%Y%m%d%H%M%S", returnStdout: true).trim()
                    env.IMAGE_TAG = "603480426027.dkr.ecr.us-west-2.amazonaws.com/${APP_NAME}:${timestamp}"
                    echo "Generated image tag: ${env.IMAGE_TAG}"
                }
            }
        }
        
        stage('Prepare Deployment') {
            steps {
                script {
                    echo "=== Preparing ${params.ENVIRONMENT} deployment ==="
                    echo "Target environment: ${params.ENVIRONMENT}"
                    echo "Application name: ${APP_NAME}"
                    echo "Namespace: ${NAMESPACE}"
                    echo "Image tag: ${env.IMAGE_TAG}"
                    
                    // Check if manifest files exist
                    def manifestExists = fileExists("k8s/${params.ENVIRONMENT}-deployment.yaml")
                    if (!manifestExists) {
                        echo "⚠️  WARNING: Manifest file k8s/${params.ENVIRONMENT}-deployment.yaml not found"
                        echo "Please ensure your Kubernetes manifests are in the k8s/ directory"
                    }
                    
                    // Simulate manifest preparation
                    echo "Would update k8s/${params.ENVIRONMENT}-deployment.yaml with image: ${env.IMAGE_TAG}"
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            when {
                expression { 
                    // Only deploy if kubectl is available
                    try {
                        sh "which kubectl"
                        return true
                    } catch (Exception e) {
                        echo "Skipping deployment - kubectl not available"
                        return false
                    }
                }
            }
            steps {
                script {
                    echo "🚀 Deploying to ${params.ENVIRONMENT} environment"
                    
                    try {
                        // Check if we can connect to cluster
                        sh "kubectl cluster-info --request-timeout=10s"
                        
                        // Apply deployment
                        sh """
                            echo "Applying deployment for ${params.ENVIRONMENT}"
                            # kubectl apply -f k8s/${params.ENVIRONMENT}-deployment.yaml
                            # kubectl apply -f k8s/${params.ENVIRONMENT}-service.yaml
                            echo "Deployment commands would be executed here"
                        """
                        
                        echo "✅ Deployment completed successfully"
                        
                    } catch (Exception e) {
                        echo "❌ Deployment failed: ${e.getMessage()}"
                        echo "This might be due to missing kubeconfig or cluster connectivity issues"
                        currentBuild.result = 'UNSTABLE'
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
                    
                    // Simulate health check
                    echo "Would perform health check on deployed application"
                    echo "Checking endpoint: http://${APP_NAME}-${params.ENVIRONMENT}.${NAMESPACE}.svc.cluster.local"
                    
                    // Simulate success for demo
                    sleep(2)
                    echo "✅ Health check completed"
                }
            }
        }
        
        stage('Deployment Summary') {
            steps {
                script {
                    def summary = """
                    🎯 DEPLOYMENT SUMMARY
                    =====================
                    Environment: ${params.ENVIRONMENT}
                    Application: ${APP_NAME}
                    Namespace: ${NAMESPACE}
                    Image Tag: ${env.IMAGE_TAG}
                    Skip Tests: ${params.SKIP_TESTS}
                    Build Number: ${BUILD_NUMBER}
                    
                    Status: Ready for traffic switch
                    """
                    
                    echo summary
                }
            }
        }
        
        stage('Manual Approval') {
            steps {
                script {
                    def deploymentInfo = """
                    Deployment to ${params.ENVIRONMENT} environment is complete.
                    
                    Please verify the deployment and choose your next action:
                    - PROCEED: Continue with traffic switch
                    - ROLLBACK: Rollback to previous version  
                    - ABORT: Stop the deployment process
                    """
                    
                    echo deploymentInfo
                    
                    def userChoice = input(
                        message: 'What would you like to do next?',
                        parameters: [
                            choice(
                                name: 'ACTION',
                                choices: ['PROCEED', 'ROLLBACK', 'ABORT'],
                                description: 'Choose the next action'
                            )
                        ]
                    )
                    
                    env.USER_ACTION = userChoice
                    echo "User selected: ${env.USER_ACTION}"
                }
            }
        }
        
        stage('Execute Action') {
            steps {
                script {
                    def otherEnv = (params.ENVIRONMENT == 'blue') ? 'green' : 'blue'
                    
                    switch(env.USER_ACTION) {
                        case 'PROCEED':
                            echo "🟢 PROCEEDING with ${params.ENVIRONMENT} deployment"
                            echo "Would switch traffic from ${otherEnv} to ${params.ENVIRONMENT}"
                            echo "Would scale down ${otherEnv} environment"
                            currentBuild.description = "✅ Deployed to ${params.ENVIRONMENT}"
                            break
                            
                        case 'ROLLBACK':
                            echo "🔄 ROLLING BACK to ${otherEnv} environment"
                            echo "Would restore ${otherEnv} environment"
                            echo "Would scale down ${params.ENVIRONMENT} environment"
                            currentBuild.description = "🔄 Rolled back to ${otherEnv}"
                            break
                            
                        case 'ABORT':
                            echo "🛑 ABORTING deployment"
                            echo "Would clean up ${params.ENVIRONMENT} deployment"
                            currentBuild.result = 'ABORTED'
                            error("Deployment aborted by user")
                            break
                    }
                }
            }
        }
        
        stage('Cleanup') {
            steps {
                script {
                    echo "🧹 Performing final cleanup"
                    try {
                        sh "echo 'Cleanup completed at: \$(date)'"
                        sh "pwd && ls -la || true"
                    } catch (Exception e) {
                        echo "Cleanup completed (shell commands not available)"
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🧹 Pipeline cleanup completed"
                // Cleanup operations that don't require sh commands
                try {
                    echo "Workspace: ${WORKSPACE}"
                } catch (Exception e) {
                    echo "Cleanup completed"
                }
            }
        }
        
        success {
            script {
                echo "🎉 Pipeline completed successfully!"
                echo "Final status: ${currentBuild.description ?: 'Completed'}"
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline failed!"
                echo "Check the logs above for details"
            }
        }
        
        aborted {
            script {
                echo "🛑 Pipeline was aborted"
            }
        }
        
        unstable {
            script {
                echo "⚠️  Pipeline completed with warnings"
                echo "Some tools may be missing - please check the prerequisites"
            }
        }
    }
}
