pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
        AWS_ACCOUNT_ID = '772706200970'
        ECR_REPO = 'patient-portal'
        IMAGE_TAG = 'latest'

        ECS_CLUSTER = 'hospital-microservices-cluster'
        ECS_SERVICE = 'patient-portal'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                docker build -t $ECR_REPO:$IMAGE_TAG .
                '''
            }
        }

        stage('Login to ECR') {
            steps {
                sh '''
                aws ecr get-login-password --region $AWS_REGION | \
                docker login --username AWS --password-stdin \
                $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
                '''
            }
        }

        stage('Push Image') {
            steps {
                sh '''
                docker tag $ECR_REPO:$IMAGE_TAG \
                $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG

                docker push \
                $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG
                '''
            }
        }

        stage('Deploy to ECS') {
            steps {
                sh '''
                aws ecs update-service \
                  --cluster $ECS_CLUSTER \
                  --service $ECS_SERVICE \
                  --force-new-deployment \
                  --region $AWS_REGION
                '''
            }
        }
    }

    post {
        always {
            sh 'docker image prune -f'
        }
    }
}
