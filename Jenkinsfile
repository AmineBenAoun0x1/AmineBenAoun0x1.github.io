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
        stage('Full Security Scan - Trivy') {
    steps {
        sh '''
        echo "Running full Trivy scan..."

        # 1. Filesystem scan (all files, all severities)
        trivy fs --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL --exit-code 0 --format json --output trivy-fs-report.json .

        # 2. Docker image scan (all layers, all severities)
        docker build -t ${DOCKER_IMAGE} .
        trivy image --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL --exit-code 0 --format json --output trivy-image-report.json ${DOCKER_IMAGE}

        # 3. Optional: dependency scan for languages (auto-detect)
        trivy fs --scanners vuln,secret,config --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL --exit-code 0 --format json --output trivy-full-report.json .
        '''
    }
}

    stage('Gitleaks Scan') {
        steps {
            echo "Running Gitleaks scan..."
                sh '''
                gitleaks detect --source . --report-path $REPORT --no-banner
        fi
        '''
    }
}


        stage('Gitleaks Scan') {
            steps {
                sh '''
                gitleaks detect --source . --report-path gitleaks-report.json --no-banner
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

                echo "📋 SonarQube configuration:"
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
                echo "🚀 Application deployed to http://localhost:4000"
                '''
            }
        }
    }

    post {
        always {
            sh '''
            echo "🧹 Cleaning up containers..."
            docker stop sonarqube || true
            docker stop jekyll-site || true
            docker rm sonarqube || true  
            docker rm jekyll-site || true
            '''
        }
        success {
            echo "✅ Pipeline completed successfully!"
            sh 'echo "Access your application at: http://localhost:4000"'
        }
        failure {
            echo "❌ Pipeline failed. Check the logs above for details."
        }
    }
}
