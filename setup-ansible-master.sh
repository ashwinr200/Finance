#!/bin/bash

# Step 1: Update and install Ansible
apt update -y
apt-get install -y software-properties-common
apt-add-repository -y ppa:ansible/ansible
apt-get update -y
apt-get install -y ansible

# Step 2: Create user 'ansadmin'
useradd -m -s /bin/bash ansadmin
echo "ansadmin:ansadmin" | chpasswd

# Step 3: Modify SSH config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 60-cloudimg-settings.conf file modification
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

# Restart SSH service
service ssh restart

# Step 4: Grant sudo access to ansadmin
echo "ansadmin ALL=(ALL:ALL) NOPASSWD:ALL" | sudo EDITOR='tee -a' visudo

# Step 5: Generate SSH key for ansadmin
su - ansadmin -c "ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa"

echo "==== Master setup complete ===="
echo "Next: Run ssh-copy-id ansadmin@<node_private_ip> from this master"
