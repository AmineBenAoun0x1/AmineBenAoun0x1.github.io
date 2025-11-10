stage('SonarQube Analysis - SIMPLE') {
    steps {
        withCredentials([string(credentialsId: 'squ_eac939f1521ef0dca88ebe75bf1d6f046407a015 ', variable: 'SONAR_TOKEN')]) {
            sh """
            # Use host network instead of custom network
            docker run --rm --network host \
                -v "\$(pwd):/usr/src" \
                -w /usr/src \
                -e SONAR_HOST_URL=http://localhost:9000 \
                sonarsource/sonar-scanner-cli:latest \
                -Dsonar.projectKey=my-jekyll-site \
                -Dsonar.sources=. \
                -Dsonar.host.url=http://localhost:9000 \
                -Dsonar.login=${SONAR_TOKEN}
            """
        }
    }
}
