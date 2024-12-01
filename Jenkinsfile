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

        stage("Execute Ansible") {
            steps {
                ansiblePlaybook credentialsId: "pet-clinic-key",
                    disableHostKeyChecking: true,
                    installation: "Petclinic Ansible",
                    inventory: "${INVENTORY_FILE}",
                    playbook: "${PLAYBOOK_FILE}"
            }    
        }    
    }
}
