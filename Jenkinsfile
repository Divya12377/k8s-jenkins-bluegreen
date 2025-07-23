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
  }

  stages {
    stage('Checkout') {
      steps {
        git 'https://github.com/Divya12377/k8s-jenkins-bluegreen.git'
      }
    }

    stage('Build & Push Docker Image') {
      steps {
        script {
          def imageTag = "${AWS_ECR}/${IMAGE_NAME}:${BUILD_NUMBER}"
          sh """
            aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${AWS_ECR}
            docker build -t ${imageTag} .
            docker push ${imageTag}
          """
          env.IMAGE = imageTag
        }
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        script {
          sh """
            sed 's|<IMAGE>|${IMAGE}|g' ${DEPLOYMENT_TEMPLATE} | kubectl apply -n ${K8S_NAMESPACE} -f -
            kubectl scale deployment nodejs-app-${params.DEPLOY_COLOR} -n ${K8S_NAMESPACE} --replicas=3
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
            kubectl patch svc ${SERVICE_NAME} -n ${K8S_NAMESPACE} \
              -p '{"spec": {"selector": {"app": "nodejs-app", "version": "${params.DEPLOY_COLOR}"}}}'
          """
        }
      }
    }

    stage('Scale Down Old') {
      steps {
        script {
          def OLD = (params.DEPLOY_COLOR == 'blue') ? 'green' : 'blue'
          sh "kubectl scale deployment nodejs-app-${OLD} -n ${K8S_NAMESPACE} --replicas=0"
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

        sh """
          sed 's|<IMAGE>|${IMAGE}|g' ${rollbackTemplate} | kubectl apply -n ${K8S_NAMESPACE} -f -
          kubectl scale deployment nodejs-app-${OLD} -n ${K8S_NAMESPACE} --replicas=3
          kubectl patch svc ${SERVICE_NAME} -n ${K8S_NAMESPACE} \
            -p '{"spec": {"selector": {"app": "nodejs-app", "version": "${OLD}"}}}'
          kubectl scale deployment nodejs-app-${params.DEPLOY_COLOR} -n ${K8S_NAMESPACE} --replicas=0
        """
      }
    }
  }
}

