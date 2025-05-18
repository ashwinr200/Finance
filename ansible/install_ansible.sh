#!/bin/bash

# This script installs and configures Ansible on the master and prepares it to manage the nodes.
# Run this script only on the Ansible master.

# Ensure you're root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo ./install_ansible.sh"
  exit 1
fi

echo "Updating and installing Ansible..."
apt update -y
apt install -y software-properties-common
apt-add-repository -y ppa:ansible/ansible
apt update -y
apt install -y ansible

echo "Creating ansadmin user (if not already present)..."
id -u ansadmin &>/dev/null || adduser --disabled-password --gecos "" ansadmin
echo "ansadmin:ansadmin" | chpasswd

echo "Granting sudo without password to ansadmin..."
echo "ansadmin ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/ansadmin

echo "Configuring SSH access..."
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Also modify cloud-init SSH config if present
CLOUD_SSH_CONF="/etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
if [ -f "$CLOUD_SSH_CONF" ]; then
  sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$CLOUD_SSH_CONF"
fi

echo "Restarting SSH service..."
systemctl restart ssh

echo "Switch to ansadmin and generate SSH keys..."
su - ansadmin -c "
if [ ! -f ~/.ssh/id_rsa ]; then
  ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa
fi
"

echo "Ansible installation complete. Add your managed nodes' private IPs to /etc/ansible/hosts under [ansiblegroup]."
