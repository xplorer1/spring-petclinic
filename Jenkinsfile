pipeline {
    agent any

    environment {
        SONARQUBE_ENV = 'Sonarqube Server'
        SONARQUBE_KEY = 'spring-petclinic'
        AWS_SERVER_IP='34.207.244.129'
        APP_PORT='8081'
        SONARQUBE_TOKEN='sqp_e6df09a3a21565b101b7fdc316499f97c5e163e7'
    }

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
                withSonarQubeEnv(installationName: SONARQUBE_ENV) {
                    sh '''
                        ./mvnw sonar:sonar \
                        -Dsonar.projectKey=$SONARQUBE_KEY \
                        -Dsonar.host.url=http://$AWS_SERVER_IP:9000 \
                        -Dsonar.login=$SONARQUBE_TOKEN \
                        -Dsonar.java.binaries=target/classes
                    '''
                }
            }
        }

        stage('Run Application') {
            steps {
                echo "Starting Petclinic application..."
                sh 'java -jar target/spring-petclinic-3.3.0-SNAPSHOT.jar --server.port=$APP_PORT'
                echo "Running application at http://$AWS_SERVER_IP:$APP_PORT"
            }
        }
    }
}
