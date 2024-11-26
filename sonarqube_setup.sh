#!/bin/bash

# Update packages
sudo apt update
sudo apt upgrade -y

# Install unzip
sudo apt install unzip -y

# Download and install SonarQube
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.2.77730.zip -P /opt
sudo unzip /opt/sonarqube-9.9.2.77730.zip -d /opt
sudo mv /opt/sonarqube-9.9.2.77730 /opt/sonarqube

# Create sonar user
sudo useradd -r -m -U -d /opt/sonarqube -s /bin/bash sonar

# Set permissions
sudo chown -R sonar:sonar /opt/sonarqube

# Configure SonarQube service
sudo tee /etc/systemd/system/sonar.service > /dev/null <<EOT
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=always

[Install]
WantedBy=multi-user.target
EOT

# Start SonarQube
sudo systemctl daemon-reload
sudo systemctl start sonar
sudo systemctl enable sonar

echo "SonarQube installed and started"