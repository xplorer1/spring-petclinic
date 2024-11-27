pipeline {
    agent any

    environment {
        SONARQUBE_ENV = 'Sonarqube Server'
        SONARQUBE_KEY = 'spring-petclinic'
        AWS_SERVER_IP='54.173.82.114'
        APP_PORT='8081'
        SONARQUBE_TOKEN='sqp_2eed0344a6ad635b3740e8f08f216f062c0f216b'
    }

    stages {
        stage('Checkout') {
            steps {
                //clone the repository
                git branch: 'main', url: 'https://github.com/xplorer1/spring-petclinic.git'
            }
        }

        stage('Compile') {
            steps {
                sh 'mvn compile'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv(installationName: SONARQUBE_ENV) {
                    sh '''
                        ./mvnw sonar:sonar \
                        -Dsonar.projectKey=$SONARQUBE_KEY \
                        -Dsonar.host.url=http://$AWS_SERVER_IP:9000 \
                        -Dsonar.login=$SONARQUBE_TOKEN
                        -Dsonar.java.binaries=target/classes
                    '''
                }
            }
        }

        stage('Build Application') {
            steps {
                //clean and build the application using Maven
                sh 'mvn clean package'
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
