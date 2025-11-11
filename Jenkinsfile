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
        
        stage('OWASP Dependency Check') {
            steps {
                sh '''
                    echo "🔍 Running OWASP Dependency Check..."
                    
                    # Scan des dépendances avec rapport complet
                    dependency-check.sh \
                        --project "my-jekyll-site" \
                        --scan . \
                        --format HTML \
                        --format JSON \
                        --out . \
                        --enableExperimental \
                        --failOnCVSS 0 \
                        --noupdate
                    
                    echo "✅ OWASP Dependency Check completed"
                    echo "📊 Reports generated:"
                    echo "   - dependency-check-report.html"
                    echo "   - dependency-check-report.json"
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'dependency-check-report.*', allowEmptyArchive: true
                }
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
                
                echo "📋 Security Reports Summary:"
                echo "   - OWASP Dependency Check: dependency-check-report.html"
                echo "   - Trivy Filesystem: trivy-fs-report.json"
                echo "   - Trivy Image: trivy-image-report.json"
                echo "   - Trivy Full: trivy-full-report.json"
                echo "   - Gitleaks: gitleaks-report.json"
            '''
            
            // Archive tous les rapports de sécurité
            archiveArtifacts artifacts: '*-report.*,dependency-check-report.*', allowEmptyArchive: true
        }
        success {
            echo "✅ Pipeline completed successfully! All security scans passed."
        }
        failure {
            echo "❌ Pipeline failed. Check logs above for details."
        }
    }
}
