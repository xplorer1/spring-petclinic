#!/bin/bash

#exit script on any error.
set -e

#declare variables.
JENKINS_PORT=8080
SONARQUBE_PORT=9000
SONARQUBE_VERSION=9.9.1.69595
JAVA_VERSION=openjdk-17-jdk
AWS_SERVER_IP=34.207.244.129
SONARQUBE_TOKEN=""

#update and install required packages.
echo "Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y wget gnupg unzip $JAVA_VERSION

#install Maven.
echo "Installing Maven..."
sudo apt install -y maven
echo "Maven version:"
mvn -version

#install jq for parsing json.
sudo apt install -y jq

#install Jenkins.
echo "Installing Jenkins..."
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install -y jenkins

#start and enable Jenkins.
sudo systemctl start jenkins
sudo systemctl enable jenkins

#get the initial admin password.
ADMIN_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
echo "Admin password for Jenkins: $ADMIN_PASSWORD"

#install SonarQube.
echo "Installing SonarQube..."
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$SONARQUBE_VERSION.zip
sudo unzip sonarqube-$SONARQUBE_VERSION.zip -d /opt/
sudo mv /opt/sonarqube-$SONARQUBE_VERSION /opt/sonarqube

#create SonarQube user.
if ! id -u sonarqube &>/dev/null; then
    #create SonarQube user only if it doesn't already exist.
    sudo useradd -m -d /opt/sonarqube -r -s /bin/bash sonarqube
    echo "SonarQube user created."
else
    echo "SonarQube user already exists."
fi

sudo chown -R sonarqube:sonarqube /opt/sonarqube

#set up SonarQube as a systemd service.
echo "Setting up SonarQube service..."
sudo bash -c 'cat > /etc/systemd/system/sonarqube.service <<EOL
[Unit]
Description=SonarQube service
After=network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOL'

#reload systemd and start SonarQube.
sudo systemctl daemon-reload
sudo systemctl start sonarqube
sudo systemctl enable sonarqube

#wait for SonarQube to start and initialize
echo "Waiting for SonarQube to fully start..."
while ! curl -s http://$AWS_SERVER_IP:$SONARQUBE_PORT > /dev/null; do sleep 10; done

#check for sonarqube system health and availability of APIs.
echo "Waiting for SonarQube to be ready for API calls..."
while true; do
    # Check SonarQube health first
    health_check=$(curl -s -u admin:admin "http://$AWS_SERVER_IP:$SONARQUBE_PORT/api/system/health")
    echo "SonarQube Health Check Response: $health_check"
    
    # Check if SonarQube is up (look for "status":"OK" in the health check response)
    if echo "$health_check" | grep -q '"health":"GREEN"'; then
        echo "Sonar is up and ready."
        # Attempt to generate a token as a readiness check
        response=$(curl -s -u admin:admin -X POST "http://$AWS_SERVER_IP:$SONARQUBE_PORT/api/user_tokens/generate" -d "name=jenkins_integration")
        echo "Response from SonarQube API: $response"

        # Check if the response contains a token
        if echo "$response" | grep -q '"token":"'; then
            # Extract the token
            SONARQUBE_TOKEN=$(echo "$response" | grep -o '"token":"[^"]*' | grep -o '[^"]*$')
            echo "SonarQube token generated: $SONARQUBE_TOKEN"
            echo "SonarQube is up and running at http://$AWS_SERVER_IP:$SONARQUBE_PORT"
            break
        else
            echo "SonarQube not ready yet, retrying in 10 seconds..."
        fi
    else
        echo "SonarQube health check failed, retrying in 10 seconds..."
    fi
    
    # Wait before retrying
    sleep 10
done

JENKINS_CLI_JAR=/var/cache/jenkins/war/WEB-INF/jenkins-cli.jar
JENKINS_URL=http://$AWS_SERVER_IP:$JENKINS_PORT

#wait for Jenkins to start and initialize.
echo "Waiting for Jenkins to fully start..."
while ! curl -s $JENKINS_URL > /dev/null; do sleep 10; done

#generate Jenkins CLI to enable us install jenkins plugins.
if [ ! -f "$JENKINS_CLI_JAR" ]; then
  echo "Downloading Jenkins CLI..."
  sudo wget -O $JENKINS_CLI_JAR $JENKINS_URL/jnlpJars/jenkins-cli.jar
fi

#add to Jenkins global environment variables
sudo java -jar "$JENKINS_CLI_JAR" -s "$JENKINS_URL" -auth "admin:$ADMIN_PASSWORD" groovy = << EOF
import jenkins.model.Jenkins
import hudson.slaves.EnvironmentVariablesNodeProperty
import hudson.slaves.NodeProperty

def jenkins = Jenkins.getInstance()
def globalNodeProperties = jenkins.getGlobalNodeProperties()
def envVarsNodePropertyList = globalNodeProperties.getAll(EnvironmentVariablesNodeProperty.class)
def newEnvVarsNodeProperty = null
def envVars = null

if (envVarsNodePropertyList == null || envVarsNodePropertyList.size() == 0) {
    newEnvVarsNodeProperty = new EnvironmentVariablesNodeProperty()
    globalNodeProperties.add(newEnvVarsNodeProperty)
    envVars = newEnvVarsNodeProperty.getEnvVars()
} else {
    envVars = envVarsNodePropertyList.get(0).getEnvVars()
}

envVars.put("SONARQUBE_TOKEN", "$SONARQUBE_TOKEN")
envVars.put("SONARQUBE_ENV", "Sonarqube Server")
envVars.put("SERVER_IP", "$AWS_SERVER_IP")
envVars.put("APP_PORT", "8081")
envVars.put("SONARQUBE_KEY", "spring-petclinic")

jenkins.save()
println "Added to Jenkins global environment variables"
EOF


CRUMB=$(curl -s -u admin:$ADMIN_PASSWORD "$JENKINS_URL/crumbIssuer/api/json" | jq -r '.crumb')
echo "CRUMB: $CRUMB"

# Verify crumb value
if [ -z "$CRUMB" ]; then
    echo "Error: Crumb is empty or invalid."
    exit 1
fi

#get the initial admin password.
ADMIN_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
echo "Admin password for Jenkins: $ADMIN_PASSWORD"

#install desired plugins.
PLUGINS=("blueocean" "sonar" "pipeline-utility-steps" "workflow-aggregator")
for plugin in "${PLUGINS[@]}"; do
  sudo java -jar $JENKINS_CLI_JAR -s $JENKINS_URL -auth admin:$ADMIN_PASSWORD install-plugin $plugin
done

#restart Jenkins after plugins installation.
sudo systemctl restart jenkins

echo "Configuring SonarQube webhook..."
curl -X POST -u admin:admin "http://$AWS_SERVER_IP:$SONARQUBE_PORT/api/webhooks/create" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "name=Jenkins&url=http://$AWS_SERVER_IP:$JENKINS_PORT/sonarqube-webhook"

echo "Setup Complete!"
echo "Jenkins is running at http://$AWS_SERVER_IP:$JENKINS_PORT"
echo "SonarQube is running at http://$AWS_SERVER_IP:$SONARQUBE_PORT"
echo "Use the following admin password to log into Jenkins: $ADMIN_PASSWORD"
echo "Use the following token as secret text when adding Sonarqube server on jenkins: $SONARQUBE_TOKEN"
