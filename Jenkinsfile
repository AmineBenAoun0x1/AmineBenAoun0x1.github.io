pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "my-jekyll-site"
        SONAR_HOST_URL = "http://localhost:9000"
    }

    stages {
        stage('Cleanup Previous Runs') {
            steps {
                sh '''
                # Clean up any existing containers
                docker stop sonarqube || true
                docker rm sonarqube || true
                docker stop jekyll-site || true
                docker rm jekyll-site || true
                '''
            }
        }

        stage('Gitleaks Scan') {
            steps {
                script {
                    echo "Running Gitleaks scan..."
                    sh '''
                    REPORT="gitleaks-report.json"
                    gitleaks detect --source . --report-path $REPORT --no-banner
                    '''
                }
            }
        }

        stage('Start SonarQube') {
            steps {
                sh '''
                # Start SonarQube container
                docker run -d --name sonarqube -p 9000:9000 \
                    -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
                    sonarqube:lts-community

                # Wait for SonarQube to be ready
                echo "Waiting for SonarQube to start..."
                sleep 120
                timeout 180 bash -c 'until curl -f -s http://localhost:9000/api/system/status > /dev/null; do echo "Waiting for SonarQube..."; sleep 10; done'
                echo "SonarQube is ready"
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                sh '''
                # Create sonar-project.properties file
                cat > sonar-project.properties << EOF
sonar.projectKey=my-jekyll-site
sonar.projectName=My Jekyll Site
sonar.projectVersion=1.0
sonar.sources=.
sonar.host.url=http://localhost:9000
sonar.login=admin
sonar.sourceEncoding=UTF-8
sonar.exclusions=**/vendor/**,**/node_modules/**,**/._*
EOF

                echo "SonarQube configuration:"
                cat sonar-project.properties | grep -v login

                # Run SonarScanner
                docker run --rm \
                  -v "\$(pwd):/usr/src" \
                  -w /usr/src \
                  --add-host=host.docker.internal:host-gateway \
                  sonarsource/sonar-scanner-cli:latest \
                  -Dproject.settings=sonar-project.properties
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${DOCKER_IMAGE} ."
            }
        }

        stage('Test Jekyll Build') {
            steps {
                sh "docker run --rm ${DOCKER_IMAGE} jekyll build --dry-run"
            }
        }

        stage('Security Scan - Trivy') {
            steps {
                sh '''
                # Scan the Docker image for vulnerabilities
                docker run --rm \
                  -v /var/run/docker.sock:/var/run/docker.sock \
                  aquasec/trivy:latest \
                  image --severity HIGH,CRITICAL \
                  --exit-code 0 \
                  ${DOCKER_IMAGE}
                '''
            }
        }

        stage('Deploy to Staging') {
            steps {
                sh '''
                docker run -d --name jekyll-site -p 4000:4000 ${DOCKER_IMAGE}
                echo "Application deployed to http://localhost:4000"
                '''
            }
        }
    }

    post {
        always {
            sh '''
            echo "Cleaning up containers..."
            docker stop sonarqube || true
            docker stop jekyll-site || true
            docker rm sonarqube || true  
            docker rm jekyll-site || true
            '''
        }
        success {
            echo "Pipeline completed successfully!"
            sh 'echo "Access your application at: http://localhost:4000"'
        }
        failure {
            echo "Pipeline failed. Check logs above for details."
        }
    }
}
