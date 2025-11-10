pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "my-jekyll-site"
        DOCKER_NETWORK = "jenkins-net"
        SONAR_HOST_URL = "http://sonarqube:9000"
    }

    stages {
        stage('Setup Docker Network') {
            steps {
                sh """
                # Create Docker network if it doesn't exist
                if ! docker network inspect ${DOCKER_NETWORK} > /dev/null 2>&1; then
                    docker network create ${DOCKER_NETWORK}
                fi
                """
            }
        }

        stage('Start SonarQube') {
            steps {
                sh """
                # Run SonarQube container if not running
                if ! docker ps --format '{{.Names}}' | grep -q '^sonarqube\$'; then
                    docker run -d --name sonarqube --network ${DOCKER_NETWORK} -p 9000:9000 sonarqube:latest
                fi
                """

                // Wait until SonarQube is reachable
                waitUntil {
                    script {
                        try {
                            sh "curl -sSf ${SONAR_HOST_URL}/api/system/status | grep -q 'UP'"
                            return true
                        } catch (Exception e) {
                            sleep 5
                            return false
                        }
                    }
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_LOGIN')]) {
                    sh """
                    docker run --rm --network ${DOCKER_NETWORK} \
                      -v \$(pwd):/usr/src \
                      -e SONAR_HOST_URL=${SONAR_HOST_URL} \
                      -e SONAR_LOGIN=${SONAR_LOGIN} \
                      -w /usr/src \
                      sonarsource/sonar-scanner-cli
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
