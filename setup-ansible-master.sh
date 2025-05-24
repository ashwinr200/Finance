#!/bin/bash

set -e  # Exit on any error

# Step 1: Update and install Ansible
apt update -y
apt-get install -y software-properties-common
apt-add-repository -y ppa:ansible/ansible
apt-get update -y
apt-get install -y ansible
apt-get install -y ansible-core
# Step 2: Create user 'ansadmin' if not exists
if ! id -u ansadmin >/dev/null 2>&1
then
    useradd -m -s /bin/bash ansadmin
    echo "ansadmin:ansadmin" | chpasswd
fi

# Step 3: Modify SSH config
sed -i 's/^#*\s*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#*\s*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*\s*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Ensure password auth in cloud config override
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

# Restart SSH service
systemctl restart ssh || service ssh restart

# Step 4: Grant sudo access to ansadmin
echo "ansadmin ALL=(ALL:ALL) NOPASSWD:ALL" | EDITOR='tee -a' visudo

# Step 5: Generate SSH key for ansadmin (if not already present)
#if [ ! -f /home/ansadmin/.ssh/id_rsa ]; then
 #   su - ansadmin -c "mkdir -p ~/.ssh && ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa"
#fi

echo "==== Master setup complete ===="
echo "Next: Run 'ssh-copy-id ansadmin@<node_private_ip>' from this master"
