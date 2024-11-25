pipeline {
    agent any

    environment {
        SONARQUBE_ENV = 'SonarQube'
    }

    stages {
        stage('Checkout') {
            steps {
                //clone the repository
                git url: 'https://github.com/xplorer1/spring-petclinic.git'
            }
        }

        stage('Build Application') {
            steps {
                //clean and build the application using Maven
                sh 'mvn clean package'
            }
        }
    }

    post {
        always {
            //clean up the workspace
            cleanWs()
        }
    }
}
