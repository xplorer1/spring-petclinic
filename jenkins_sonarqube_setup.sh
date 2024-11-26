#!/bin/bash

# Exit script on any error
set -e

# Variables
JENKINS_PORT=8080
SONARQUBE_PORT=9000
SONARQUBE_VERSION=9.9.1.69595
JAVA_VERSION=openjdk-17-jdk
AWS_SERVER_IP=18.207.117.242

# Update and install required packages
echo "Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y wget gnupg unzip $JAVA_VERSION

# Install Maven
echo "Installing Maven..."
sudo apt install -y maven
echo "Maven version:"
mvn -version

# Install Jenkins
echo "Installing Jenkins..."
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install -y jenkins

# Start and enable Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Install SonarQube
echo "Installing SonarQube..."
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$SONARQUBE_VERSION.zip
sudo unzip sonarqube-$SONARQUBE_VERSION.zip -d /opt/
sudo mv /opt/sonarqube-$SONARQUBE_VERSION /opt/sonarqube

# Create SonarQube user
sudo useradd -m -d /opt/sonarqube -r -s /bin/bash sonarqube
sudo chown -R sonarqube:sonarqube /opt/sonarqube

# Set up SonarQube as a systemd service
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

# Reload systemd and start SonarQube
sudo systemctl daemon-reload
sudo systemctl start sonarqube
sudo systemctl enable sonarqube

# Install Jenkins Plugins
echo "Installing Jenkins plugins..."
JENKINS_CLI_JAR=/var/cache/jenkins/war/WEB-INF/jenkins-cli.jar
JENKINS_URL=http://$AWS_SERVER_IP:$JENKINS_PORT

# Wait for Jenkins to start and initialize
echo "Waiting for Jenkins to fully start..."
while ! curl -s $JENKINS_URL > /dev/null; do sleep 10; done

# Generate Jenkins CLI
if [ ! -f "$JENKINS_CLI_JAR" ]; then
  echo "Downloading Jenkins CLI..."
  sudo wget -O $JENKINS_CLI_JAR $JENKINS_URL/jnlpJars/jenkins-cli.jar
fi

# Get the initial admin password
ADMIN_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
echo "Admin password for Jenkins: $ADMIN_PASSWORD"

# Install desired plugins
PLUGINS=("blueocean" "sonar" "pipeline-utility-steps" "workflow-aggregator")
for plugin in "${PLUGINS[@]}"; do
  sudo java -jar $JENKINS_CLI_JAR -s $JENKINS_URL -auth admin:$ADMIN_PASSWORD install-plugin $plugin
done

# Restart Jenkins after plugin installation
sudo systemctl restart jenkins

echo "Setup Complete!"
echo "Jenkins is running at http://$AWS_SERVER_IP:$JENKINS_PORT"
echo "SonarQube is running at http://$AWS_SERVER_IP:$SONARQUBE_PORT"
echo "Use the following admin password to log into Jenkins: $ADMIN_PASSWORD"
