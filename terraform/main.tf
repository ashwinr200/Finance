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

# Install Ansible properly
apt-get install -y software-properties-common
apt-add-repository --yes --update ppa:ansible/ansible
apt-get update -y
apt-get install -y ansible-core ansible sshpass

# Configure basic ansible settings
mkdir -p /etc/ansible
echo -e "[defaults]\nhost_key_checking = False" > /etc/ansible/ansible.cfg
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
              sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
              systemctl restart sshd
              EOF
}
