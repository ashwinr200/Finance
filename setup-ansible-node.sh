#!/bin/bash
set -e  # Exit on any error

# Step 1: Create user 'ansadmin' if not exists
if ! id -u ansadmin >/dev/null 2>&1; then
    useradd -m -s /bin/bash ansadmin
    echo "ansadmin:ansadmin" | chpasswd
fi

# Step 2: Modify SSH config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

# Restart SSH service
if command -v systemctl &>/dev/null; then
    systemctl restart ssh
else
    service ssh restart
fi

# Step 3: Grant sudo access to ansadmin
echo "ansadmin ALL=(ALL:ALL) NOPASSWD:ALL" | EDITOR='tee -a' visudo

echo "==== Node setup complete ===="
echo "Ready to accept SSH key from Ansible master (ansadmin)"
