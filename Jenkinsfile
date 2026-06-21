pipeline {
  agent any

  parameters {
    string(name: 'TAG_NAME', defaultValue: 'latest', description: 'Docker image tag to push and deploy')
  }

  environment {
    AWS_REGION      = 'us-east-1'
    TERRAFORM_DIR   = 'terraform-ecs'
    APPOINTMENT_IMAGE = 'vikash3117/appointmentservice'
    PATIENT_IMAGE     = 'vikash3117/patientservic'
    DOCTOR_IMAGE      = 'vikash3117/doctorservice'
    PORTAL_IMAGE      = 'vikash3117/patient-portal'
    DOCKER_IMAGE      = "patient-portal:${BUILD_NUMBER}"
    DOCKER_REGISTRY   = 'docker.io'
    DOCKER_REPO       = 'vikash3117/patient-portal'
    REPO_URL          = 'https://github.com/vikashsum/patient-portal.git'
  }

  stages {
    stage('Checkout') {
      steps {
        echo '====== Checking out repository ======'
        git branch: 'main', url: "${REPO_URL}"
      }
    }

    stage('Build') {
      steps {
        echo '====== Installing and building frontend ======'
        sh '''
          echo "Running frontend build inside node:18-alpine container"
          docker run --rm -v "$PWD":/app -w /app node:18-alpine sh -c "npm install && npm run lint || true && npm run build"

          echo '====== Building Docker image (nginx) ======'
          docker build -t ${DOCKER_IMAGE} .
          docker images | grep patient-portal || true
        '''
      }
    }

    stage('Push') {
      steps {
        echo '====== Pushing to Docker Hub ======'
        script {
          withCredentials([usernamePassword(credentialsId: 'docker-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
            sh '''
              echo "Logging into Docker Hub..."
              echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin

              IMAGE=${DOCKER_REPO}:${TAG_NAME}
              docker tag ${DOCKER_IMAGE} ${IMAGE}

              echo "Pushing image to Docker Hub..."
              docker push ${IMAGE}

              echo "Image pushed successfully: ${IMAGE}"
            '''
          }
        }
      }
    }

    stage('Terraform Format') {
      steps {
        echo '====== Formatting Terraform ======'
        dir("${TERRAFORM_DIR}") {
          sh 'terraform fmt -recursive'
        }
      }
    }

    stage('Terraform Init') {
      steps {
        echo '====== Initializing Terraform ======'
        script {
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
            dir("${TERRAFORM_DIR}") {
              sh '''
                export AWS_REGION=${AWS_REGION}
                export AWS_DEFAULT_REGION=${AWS_REGION}
                export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

                terraform init -input=false
              '''
            }
          }
        }
      }
    }

    stage('Terraform Plan') {
      steps {
        echo '====== Planning ECS Terraform ======'
        script {
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
            dir("${TERRAFORM_DIR}") {
              sh '''
                export AWS_REGION=${AWS_REGION}
                export AWS_DEFAULT_REGION=${AWS_REGION}
                export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

                terraform plan -out=tfplan -input=false \
                  -var "appointment_image=${APPOINTMENT_IMAGE}" \
                  -var "patient_image=${PATIENT_IMAGE}" \
                  -var "doctor_image=${DOCTOR_IMAGE}" \
                  -var "portal_image=${PORTAL_IMAGE}" \
                  -var "image_tag=${TAG_NAME}"
              '''
            }
          }
        }
      }
    }

    stage('Terraform Apply') {
      steps {
        echo '====== Applying ECS Terraform ======'
        script {
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
            dir("${TERRAFORM_DIR}") {
              sh '''
                export AWS_REGION=${AWS_REGION}
                export AWS_DEFAULT_REGION=${AWS_REGION}
                export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

                terraform apply -input=false -auto-approve tfplan
              '''
            }
          }
        }
      }
    }

    stage('Show Load Balancer') {
      steps {
        echo '====== ECS Load Balancer DNS ======'
        script {
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
            dir("${TERRAFORM_DIR}") {
              sh '''
                export AWS_REGION=${AWS_REGION}
                export AWS_DEFAULT_REGION=${AWS_REGION}
                export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

                terraform output -raw lb_dns_name
              '''
            }
          }
        }
      }
    }
  }

  post {
    success {
      echo '✅ patient-portal pipeline completed successfully'
    }
    failure {
      echo '❌ patient-portal pipeline failed'
    }
  }
}
