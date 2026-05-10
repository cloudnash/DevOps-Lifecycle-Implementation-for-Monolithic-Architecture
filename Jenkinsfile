pipeline {
    agent any
    environment {
        DOCKER_IMAGE_NAME = 'nashit836/analytics-app'
        DOCKER_IMAGE_TAG = "${BUILD_NUMBER}"
    }
    stages {
        stage('Code Checkout') {
            steps {
                checkout scm
                echo "✅ Code checkout completed"
            }
        }
        stage('Docker Build and Push') {
            steps {
                script {
                    def dockerImage = docker.build("${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}")
                    docker.withRegistry('https://registry.hub.docker.com', 'dockerhub-credentials') {
                        dockerImage.push("${DOCKER_IMAGE_TAG}")
                        dockerImage.push("latest")
                    }
                    echo "✅ Docker image pushed successfully"
                }
            }
        }
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    sh 'kubectl apply -f kubernetes/'
                    sh 'kubectl rollout status deployment/analytics-app -n analytics-prod'
                    echo "✅ Kubernetes deployment completed"
                }
            }
        }
    }
}
