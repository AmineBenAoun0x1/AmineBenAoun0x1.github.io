pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "my-jekyll-site"
        SONAR_HOST_URL = "http://localhost:9000"
        SONAR_LOGIN = credentials('sonar-token') // Jenkins secret text
    }

    stages {
        stage('SonarQube Analysis') {
            steps {
                // Run SonarQube scanner in Docker
                sh "docker run --rm -e SONAR_HOST_URL=${SONAR_HOST_URL} -e SONAR_LOGIN=${SONAR_LOGIN} sonarsource/sonar-scanner-cli"
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${DOCKER_IMAGE} ."
            }
        }

        stage('Test Jekyll Build') {
            steps {
                // Escape $ for shell command
                sh "docker run --rm -v \$(pwd):/srv/jekyll ${DOCKER_IMAGE} jekyll build --dry-run"
            }
        }

        stage('Deploy') {
            steps {
                sh "docker run --rm -d -p 4000:4000 ${DOCKER_IMAGE}"
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully! Jekyll site deployed at http://localhost:4000"
        }
        failure {
            echo "Pipeline failed. Check logs for details."
        }
    }
}
