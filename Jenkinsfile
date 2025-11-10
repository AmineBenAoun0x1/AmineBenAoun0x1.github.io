pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "my-jekyll-site"
        SONAR_HOST_URL = "http://sonarqube:9000" // Use container name instead of localhost
        DOCKER_NETWORK = "jenkins-net" // Docker network name
    }

    stages {
        stage('Setup Docker Network') {
            steps {
                sh """
                # Create network if it doesn't exist
                if ! docker network inspect ${DOCKER_NETWORK} > /dev/null 2>&1; then
                    docker network create ${DOCKER_NETWORK}
                fi
                """
            }
        }

        stage('Start SonarQube') {
            steps {
                sh """
                # Run SonarQube container if not already running
                if ! docker ps --format '{{.Names}}' | grep -q '^sonarqube\$'; then
                    docker run -d --name sonarqube --network ${DOCKER_NETWORK} -p 9000:9000 sonarqube:latest
                    echo "Waiting 60 seconds for SonarQube to start..."
                    sleep 60
                fi
                """
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_LOGIN')]) {
                    sh """
                    docker run --rm --network ${DOCKER_NETWORK} \
                       DSONAR_HOST_URL=${SONAR_HOST_URL} \
                       DSONAR_PROJECT_KEY=my-jekyll-site \
                       DSONAR_SOURCES=. \
                       DSONAR_TOKEN=squ_eac939f1521ef0dca88ebe75bf1d6f046407a015 \
                      sonarsource/sonar-scanner-cli:5.0
                    """
                }
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

    post {
        success {
            echo "Pipeline completed successfully! Jekyll site deployed at http://localhost:4000"
        }
        failure {
            echo "Pipeline failed. Check logs for details."
        }
    }
}
