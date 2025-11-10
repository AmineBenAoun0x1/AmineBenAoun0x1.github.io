pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "my-jekyll-site"
        SONAR_HOST_URL = "http://localhost:9000"
        SONAR_LOGIN = credentials('sonar-token') // Add your SonarQube token in Jenkins
    }

    stages {
        stage('Clone Repo') {
            steps {
                git 'https://github.com/AmineBenAoun0x1/AmineBenAoun0x1.github.io.git'
            }
        }

        stage('SonarQube Analysis') {
            steps {
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
                sh "docker run --rm -v \$(pwd):/srv/jekyll ${DOCKER_IMAGE} jekyll build --dry-run"
            }
        }

        stage('Deploy') {
            steps {
                sh "docker run --rm -d -p 4000:4000 ${DOCKER_IMAGE}"
            }
        }
    }
}
