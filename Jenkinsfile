pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "my-jekyll-site"
    }

    stages {
        stage('Cleanup Previous Runs') {
            steps {
                sh '''
                # Clean up any existing containers
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

                # 2. Build Docker image
                docker build -t ${DOCKER_IMAGE} .

                # 3. Docker image scan (all layers, all severities)
                trivy image --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL --exit-code 0 --format json --output trivy-image-report.json ${DOCKER_IMAGE}

                # 4. Optional: Full scan including secrets and misconfigurations
                trivy fs --scanners vuln,secret,config --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL --exit-code 0 --format json --output trivy-full-report.json .
                '''
            }
        }

        stage('Gitleaks Scan') {
            steps {
                sh '''
                echo "Running Gitleaks scan..."
                gitleaks detect --source . --report-path gitleaks-report.json --no-banner || true
                echo "Gitleaks scan finished. Report saved as gitleaks-report.json"
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
            docker stop jekyll-site || true
            docker rm jekyll-site || true
            '''
        }
        success {
            echo "Pipeline completed successfully!"
        }
        failure {
            echo "Pipeline failed. Check logs above for details."
        }
    }
}
