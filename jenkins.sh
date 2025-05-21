#!/bin/bash
# USE UBUNTU20.04 - INSTANCE: 2GB RAM + 2VCPU MIN - WILL ONLY WORK
sudo apt update -y
sudo apt install openjdk-17-jdk -y
sudo apt update -y
sudo apt install maven -y
sudo apt-get install -y git
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update -y
sudo apt install jenkins -y
service jenkins start
cat /var/lib/jenkins/secrets/initialAdminPassword
sudo usermod -aG docker jenkins
#chmod 777 jenkins.sh
#./jenkins.sh

# Install Docker
echo "Installing Docker..."
sudo apt-get install -y docker.io
echo "Adding Jenkins user to Docker group..."
sudo usermod -aG docker jenkins

# Install Terraform
echo "Installing Terraform..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update -y
sudo apt-get install -y terraform

# Install Prometheus
echo "Downloading Prometheus..."
wget https://github.com/prometheus/prometheus/releases/download/v2.34.0/prometheus-2.34.0.linux-amd64.tar.gz
tar zxvf prometheus-2.34.0.linux-amd64.tar.gz
