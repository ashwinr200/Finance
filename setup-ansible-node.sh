#!/bin/bash

# Step 1: Create user 'ansadmin'
useradd -m -s /bin/bash ansadmin
echo "ansadmin:ansadmin" | chpasswd

# Step 2: Modify SSH config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 60-cloudimg-settings.conf file modification
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

# Restart SSH service
service ssh restart

# Step 3: Grant sudo access to ansadmin
echo "ansadmin ALL=(ALL:ALL) NOPASSWD:ALL" | sudo EDITOR='tee -a' visudo


echo "==== Node setup complete ===="
echo "Ready to accept SSH key from Ansible master (ansadmin)"
