provider "aws" {
  region = var.region
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

resource "aws_instance" "master" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.selected.ids[0]
  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${var.env}_master"
    Role = "master"
  }

 user_data = <<-EOF
#!/bin/bash
# Create ansadmin user
useradd -m -s /bin/bash ansadmin
echo 'ansadmin ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/ansadmin

# Configure SSH access
mkdir -p /home/ansadmin/.ssh
touch /home/ansadmin/.ssh/authorized_keys
if [ -f /home/ubuntu/.ssh/authorized_keys ]; then
  cat /home/ubuntu/.ssh/authorized_keys >> /home/ansadmin/.ssh/authorized_keys
fi

# Set proper permissions
chown -R ansadmin:ansadmin /home/ansadmin/.ssh
chmod 700 /home/ansadmin/.ssh
chmod 600 /home/ansadmin/.ssh/authorized_keys

# Fix potential apt issues
apt-get update -y
apt-get install -y --fix-broken
apt-get autoremove -y

while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
  echo "Waiting for other apt processes to finish..."
  sleep 5
done


# Install Ansible properly
apt-get install -y software-properties-common
apt-add-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible-core ansible sshpass

# Configure basic ansible settings
mkdir -p /etc/ansible
echo -e "[defaults]\nhost_key_checking = False" > /etc/ansible/ansible.cfg

# Enable password authentication temporarily
# PermitRootLogin yes
if grep -q "^#*PermitRootLogin" /etc/ssh/sshd_config; then
  sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
else
  echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
fi

# PasswordAuthentication yes
if grep -q "^#*PasswordAuthentication" /etc/ssh/sshd_config; then
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
else
  echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
fi

# PubkeyAuthentication yes
if grep -q "^#*PubkeyAuthentication" /etc/ssh/sshd_config; then
  sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
else
  echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
fi

if grep -q "^#*PasswordAuthentication" /etc/ssh/sshd_config.d/60-cloudimg-settings.conf; then
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
else
  echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
fi

# Restart sshd to apply config changes
systemctl restart ssh

# Wait 30 seconds before instance is ready for SSH
sleep 5

EOF
}

resource "aws_instance" "node" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.selected.ids[0]
  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${var.env}_node"
    Role = "node"
  }

   user_data = <<-EOF
#!/bin/bash
# Create ansadmin user with password
useradd -m -s /bin/bash ansadmin
echo "ansadmin:ansadmin" | chpasswd
echo 'ansadmin ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/ansadmin

# Enable password authentication temporarily
# PermitRootLogin yes
if grep -q "^#*PermitRootLogin" /etc/ssh/sshd_config; then
  sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
else
  echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
fi

# PasswordAuthentication yes
if grep -q "^#*PasswordAuthentication" /etc/ssh/sshd_config; then
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
else
  echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
fi

# PubkeyAuthentication yes
if grep -q "^#*PubkeyAuthentication" /etc/ssh/sshd_config; then
  sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
else
  echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
fi

if grep -q "^#*PasswordAuthentication" /etc/ssh/sshd_config.d/60-cloudimg-settings.conf; then
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
else
  echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
fi


# Restart sshd
systemctl restart ssh
EOF
}
