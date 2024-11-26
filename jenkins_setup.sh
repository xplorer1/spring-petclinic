#!/bin/bash

# Update packages
sudo apt update
sudo apt upgrade -y

# Install Java
sudo apt install openjdk-17-jdk -y

# Install Jenkins
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install jenkins -y

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Print initial admin password
echo "Initial Jenkins admin password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Wait for Jenkins to start up
echo "Waiting for Jenkins to start..."
while [[ $(curl -s -w "%{http_code}" http://localhost:8080 -o /dev/null) != "403" ]]; do
  sleep 10
done

# Get the initial admin password
JENKINS_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
echo "Initial Jenkins admin password: $JENKINS_PASSWORD"

# Download Jenkins CLI
wget http://localhost:8080/jnlpJars/jenkins-cli.jar

# Create a list of plugins to install
JENKINS_PLUGINS=(
  "blueocean"
  "workflow-aggregator"
  "git"
  "pipeline-stage-view"
  "sonar"
)

# Install plugins
for plugin in "${JENKINS_PLUGINS[@]}"; do
  java -jar jenkins-cli.jar -s http://localhost:8080 -auth admin:$JENKINS_PASSWORD install-plugin $plugin
done

# Restart Jenkins to apply changes
java -jar jenkins-cli.jar -s http://localhost:8080 -auth admin:$JENKINS_PASSWORD safe-restart

echo "Jenkins setup complete. Please access Jenkins at http://your-server-ip:8080"