pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                //clone the repository
                git branch: 'main', url: 'https://github.com/xplorer1/spring-petclinic.git'
            }
        }

        stage('Compile and build application') {
            steps {
                //clean and build the application using Maven
                sh 'mvn clean package'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv(installationName: env.SONARQUBE_ENV) {
                    sh '''
                        ./mvnw sonar:sonar \
                        -Dsonar.projectKey=${SONARQUBE_KEY} \
                        -Dsonar.host.url=http://${SERVER_IP}:9000 \
                        -Dsonar.login=$SONARQUBE_TOKEN \
                        -Dsonar.java.binaries=target/classes
                    '''
                }
            }
        }

        stage('Run Application') {
            steps {
                echo "Starting Petclinic application in the background..."
                sh '''
                    nohup java -jar target/spring-petclinic-3.3.0-SNAPSHOT.jar --server.port=${APP_PORT} > petclinic.log 2>&1 &
                '''
                echo "Running application at http://${SERVER_IP}:${APP_PORT}"
            }
        }

    }
}
