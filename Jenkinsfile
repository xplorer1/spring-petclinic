pipeline {
    agent any

    environment {
        SONARQUBE_ENV = 'SonarQube'
        SONARQUBE_KEY = 'spring-petclinic'
        AWS_SERVER_IP='54.163.217.206'
        APP_PORT='8081'
    }

    stages {
        stage('Checkout') {
            steps {
                //clone the repository
                git branch: 'main', url: 'https://github.com/xplorer1/spring-petclinic.git'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv(SONARQUBE_ENV) {
                    sh '''
                        ./mvnw sonar:sonar \
                        -Dsonar.projectKey=$SONARQUBE_KEY \
                        -Dsonar.host.url=http://$AWS_SERVER_IP:9000 \
                        -Dsonar.login=$SONARQUBE_TOKEN
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
