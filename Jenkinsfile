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

        stage('Deploy with ansible') {
            steps {
                echo "Running Ansible playbook to deploy to ProductionServer..."
                sh """
                    ansible-playbook -i ${INVENTORY_FILE} ${PLAYBOOK_FILE} \
                    -e app_package=target/spring-petclinic-3.3.0-SNAPSHOT.jar \
                    -e server_port=${APP_PORT} --private-key=/home/ubuntu/.ssh/dev-key-pair.pem
                """
            }
        }
    }
}
