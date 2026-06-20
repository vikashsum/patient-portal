pipeline {
  agent any

  parameters {
    string(name: 'TAG_NAME', defaultValue: 'latest', description: 'Docker image tag to push (e.g. tagname)')
  }

  environment {
    DOCKER_IMAGE = "patient-portal:${BUILD_NUMBER}"
    DOCKER_REGISTRY = 'docker.io'
    DOCKER_REPO = 'vikash3117/patient-portal'
    REPO_URL = 'https://github.com/vikashsum/patient-portal.git'
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
        // Run npm tasks inside an official Node container (requires Docker on agent)
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
  }

  post {
    success { echo '✅ patient-portal pipeline completed successfully' }
    failure { echo '❌ patient-portal pipeline failed' }
  }
}
