pipeline {
  agent any
  tools { maven 'M2_HOME' }

  environment {
    SONARQUBE_SERVER      = 'sq1'
    DOCKERHUB_CREDENTIALS = credentials('jenkins-dockhub')
    NOTIFY_RECIPIENTS = 'ilyess.saoudi@gmail.com'   
    ENABLE_EMAIL      = '1'               
    IMAGE_REPO       = 'simpledotnet/devsecops-jenkins'

    // Kubernetes (Minikube + default namespace)
    KUBECONFIG       = '/var/lib/jenkins/.kube/config'
    KUBE_CONTEXT     = 'minikube'
    KUBE_NAMESPACE   = 'default'

    // Spring Boot (match your YAML)
    DEPLOYMENT_NAME  = 'springboot-deployment'
    CONTAINER_NAME   = 'springboot'
    APP_LABEL        = 'springboot'

    // MySQL (match your YAML)
    MYSQL_DEPLOYMENT = 'mysql-deployment'
    MYSQL_LABEL      = 'mysql'
  }

  options { timestamps() }

  stages {
    stage('Checkout') {
      steps {
        echo '📦 Checkout'
        git branch: 'main', url: 'https://github.com/ilyessaoudi/devops-main.git'
      }
    }
stage('Secrets Scan (Gitleaks)') {
  steps {
    // Set GITLEAKS_FAIL=1 in Jenkins to fail the build on leaks
    sh '''
GITLEAKS_FLAGS="--no-banner --redact --report-format=json --report-path=gitleaks-report.json -s ."

      if [ "${GITLEAKS_FAIL:-0}" = "1" ]; then
        # Fail pipeline if leaks are found (gitleaks exits 1)
        gitleaks detect $GITLEAKS_FLAGS
      else 
        # Do not fail pipeline; just produce a report
        gitleaks detect $GITLEAKS_FLAGS || true
     fi
    '''
  }
  post {
    always {
      archiveArtifacts artifacts: 'gitleaks-report.json', allowEmptyArchive: true
    }
  }
}

    stage('Build & Test (Maven)') {
      steps {
        echo '⚙️ Build & Test'
        dir('backend') { sh 'mvn -B clean verify' }
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: 'backend/**/target/surefire-reports/*.xml'
        }
      }
    }

    stage('SonarQube Analysis & Quality Gate') {
      steps {
        script {
          echo '🔍 SonarQube'
          withSonarQubeEnv(env.SONARQUBE_SERVER) {
            dir('backend') {
              sh '''
                mvn -B sonar:sonar \
                  -Dsonar.projectKey=backend \
                  -Dsonar.projectName=backend \
                  -Dsonar.host.url=$SONAR_HOST_URL
              '''
            }
          }
          echo '⏳ Waiting for Quality Gate...'
          timeout(time: 10, unit: 'MINUTES') {
            def qg = waitForQualityGate()
            if (qg.status != 'OK') error "❌ Quality Gate failed: ${qg.status}"
            echo "✅ Quality Gate passed!"
          }
        }
      }
    }
    
   stage('Dependency Scan (OWASP Dependency-Check)') {
  steps {
    script {
      echo '🔍 OWASP Dependency-Check'
      // Clean any old reports
      sh 'rm -f dependency-check-report.* || true'

      // Generate HTML + XML at workspace root
      dependencyCheck(
        additionalArguments: "--scan backend --out . --format HTML --format XML --enableRetired",
        odcInstallation: 'DP-Check'
      )
    }
  }
  post {
    always {
      echo "📄 Archiving DC reports..."
      archiveArtifacts artifacts: 'dependency-check-report.html,dependency-check-report.xml', allowEmptyArchive: true
    }
  }
}

stage('Block on Critical: Dependency-Check') {
  steps {
    dependencyCheckPublisher(
      pattern: 'dependency-check-report.xml',
      failedTotalCritical: 0   // fail if ≥ 1 critical
    )
  }
}

    stage('Set Build Vars') {
      steps {
        script {
          env.SHORT_SHA = sh(script: "git rev-parse --short=7 HEAD", returnStdout: true).trim()
          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.SHORT_SHA}"
          echo "🧾 Image tag: ${env.IMAGE_REPO}:${env.IMAGE_TAG}"
        }
      }
    }

    stage('Login to Docker Hub') {
      steps {
        sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'
      }
    }

    stage('Build & Push Docker Image') {
      steps {
        script {
          echo '🔨 Docker build & push'
          sh """
            docker build -t ${IMAGE_REPO}:${IMAGE_TAG} -t ${IMAGE_REPO}:latest ./backend
            docker push ${IMAGE_REPO}:${IMAGE_TAG}
            docker push ${IMAGE_REPO}:latest
          """
        }
      }
    }
stage('Trivy Scan') {
  steps {
    sh '''#!/usr/bin/env bash
set -e

echo "🔍 Fast Trivy vulnerability scan..."
trivy --version || true

# Generate a human-readable report (never fail this step)
trivy image \
  --scanners vuln \
  --no-progress \
  --skip-java-db-update \
  --timeout 20m \
  --severity HIGH,CRITICAL \
  --format table \
  --output trivy-report.txt \
  ${IMAGE_REPO}:${IMAGE_TAG} || true

echo "📄 Report generated: trivy-report.txt"

# ⛔ Enforce: fail the build if any CRITICAL is found
trivy image \
  --scanners vuln \
  --no-progress \
  --skip-java-db-update \
  --timeout 20m \
  --severity CRITICAL \
  --exit-code 1 \
  ${IMAGE_REPO}:${IMAGE_TAG}
'''
  }
  post {
    always {
      archiveArtifacts artifacts: 'trivy-report.txt', allowEmptyArchive: true
    }
  }
}



    stage('Docker Logout') {
      steps {
        echo '🔒 Docker logout'
        sh 'docker logout'
      }
    }

    stage('Warm Image into Minikube') {
      steps {
        script {
          echo "📦 Preload image into Minikube: ${IMAGE_REPO}:${IMAGE_TAG}"
          sh """
            kubectl config use-context ${KUBE_CONTEXT}
            docker image inspect ${IMAGE_REPO}:${IMAGE_TAG} >/dev/null
            minikube image load ${IMAGE_REPO}:${IMAGE_TAG}
          """
        }
      }
    }

    stage('Prepare Kubernetes Context') {
      steps {
        script {
          echo "⎈ Kube context"
          sh """
            kubectl config use-context ${KUBE_CONTEXT}
            kubectl config current-context
          """
        }
      }
    }

    stage('Apply Manifests (PV/PVC → MySQL → App)') {
      steps {
        script {
          echo '📜 Apply PV/PVC'
          sh """
            kubectl -n ${KUBE_NAMESPACE} apply -f backend/k8s/mysql_pv.yaml
            kubectl -n ${KUBE_NAMESPACE} apply -f backend/k8s/mysql_pvc.yaml
          """

          echo '📜 Apply MySQL'
          sh """
            kubectl -n ${KUBE_NAMESPACE} apply -f backend/k8s/mysql_deployment.yaml
            kubectl -n ${KUBE_NAMESPACE} apply -f backend/k8s/mysql_service.yaml
          """

          echo '📜 Apply Spring Boot'
          sh """
            kubectl -n ${KUBE_NAMESPACE} apply -f backend/k8s/springboot_configmap.yaml
            kubectl -n ${KUBE_NAMESPACE} apply -f backend/k8s/springboot_secret.yaml
            kubectl -n ${KUBE_NAMESPACE} apply -f backend/k8s/springboot_deployment.yaml
            kubectl -n ${KUBE_NAMESPACE} apply -f backend/k8s/springboot_service.yaml
          """
        }
      }
    }

    stage('Wait for MySQL Ready') {
      steps {
        script {
          echo '⏳ MySQL readiness'
          sh """
            kubectl -n ${KUBE_NAMESPACE} rollout status deployment/${MYSQL_DEPLOYMENT} --timeout=10m || true
            kubectl -n ${KUBE_NAMESPACE} wait pod -l app=${MYSQL_LABEL} --for=condition=Ready --timeout=10m || true
            kubectl -n ${KUBE_NAMESPACE} get pods -l app=${MYSQL_LABEL} -o wide
          """
        }
      }
    }

    stage('Rollout New Image (Spring Boot)') {
      steps {
        script {
          echo "🚀 Set image: ${IMAGE_REPO}:${IMAGE_TAG}"
          sh """
            kubectl -n ${KUBE_NAMESPACE} set image deployment/${DEPLOYMENT_NAME} \
              ${CONTAINER_NAME}=${IMAGE_REPO}:${IMAGE_TAG}

            echo '⏳ Wait rollout'
            kubectl -n ${KUBE_NAMESPACE} rollout status deployment/${DEPLOYMENT_NAME} --timeout=10m

            echo '⏳ Wait pods Ready'
            kubectl -n ${KUBE_NAMESPACE} wait pod -l app=${APP_LABEL} --for=condition=Ready --timeout=10m

            echo '✅ Spring Boot deployed.'
          """
        }
      }
      post {
        failure {
          script {
            echo '🔍 Collecting minimal diagnostics...'
            sh """
              kubectl -n ${KUBE_NAMESPACE} get all -o wide
              kubectl -n ${KUBE_NAMESPACE} describe deployment/${DEPLOYMENT_NAME} || true
              kubectl -n ${KUBE_NAMESPACE} get pods -l app=${APP_LABEL} -o name | xargs -r -n1 kubectl -n ${KUBE_NAMESPACE} describe || true
              for p in \$(kubectl -n ${KUBE_NAMESPACE} get pods -l app=${APP_LABEL} -o name); do
                echo "---- \$p logs ----"
                kubectl -n ${KUBE_NAMESPACE} logs --tail=200 \$p || true
              done
            """
          }
        }
      }
    }

    stage('Post-Deploy Info') {
      steps {
        script {
          echo 'ℹ️ Status'
          sh "kubectl -n ${KUBE_NAMESPACE} get svc,deploy,po -o wide"
        }
      }
    }
  }
  
  post {
  success {
    script {
      if (env.ENABLE_EMAIL == '1') {
        emailext(
          subject: "✅ ${env.JOB_NAME} #${env.BUILD_NUMBER} succeeded",
          to: env.NOTIFY_RECIPIENTS,
          mimeType: 'text/plain',
          body: """Build succeeded.

Job: ${env.JOB_NAME}
Build: #${env.BUILD_NUMBER}
Branch: ${env.GIT_BRANCH ?: 'main'}
Image: ${env.IMAGE_REPO}:${env.IMAGE_TAG}

Details: ${env.BUILD_URL}
Artifacts:
 - dependency-check-report.html / .xml
 - trivy-report.txt
 - gitleaks-report.json
"""
        )
      }
    }
  }

  unstable {
    script {
      if (env.ENABLE_EMAIL == '1') {
        emailext(
          subject: "⚠️ ${env.JOB_NAME} #${env.BUILD_NUMBER} unstable",
          to: env.NOTIFY_RECIPIENTS,
          attachmentsPattern: 'dependency-check-report.html,dependency-check-report.xml,trivy-report.txt,gitleaks-report.json',
          mimeType: 'text/plain',
          body: """Build is UNSTABLE.

Job: ${env.JOB_NAME}
Build: #${env.BUILD_NUMBER}
Details: ${env.BUILD_URL}

Attached: DC/Trivy/Gitleaks reports (if present).
"""
        )
      }
    }
  }

  failure {
    script {
      if (env.ENABLE_EMAIL == '1') {
        emailext(
          subject: "❌ ${env.JOB_NAME} #${env.BUILD_NUMBER} FAILED",
          to: env.NOTIFY_RECIPIENTS,
          attachLog: true,
          attachmentsPattern: 'dependency-check-report.html,dependency-check-report.xml,trivy-report.txt,gitleaks-report.json',
          mimeType: 'text/plain',
          body: """Build FAILED.

Job: ${env.JOB_NAME}
Build: #${env.BUILD_NUMBER}
Details: ${env.BUILD_URL}

Most common causes in this pipeline:
 - OWASP Dependency-Check CRITICALs (Block on Critical stage)
 - Trivy CRITICALs (Trivy Scan stage)
 - SonarQube Quality Gate

Attached: console log + security reports.
"""
        )
      }
    }
  }
}

}
