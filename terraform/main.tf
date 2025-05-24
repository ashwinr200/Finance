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
set -x

wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/setup-ansible-master.sh -O /tmp/setup-ansible-master.sh
chmod +x /tmp/setup-ansible-master.sh
/tmp/setup-ansible-master.sh

wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/prometheus.sh -O /tmp/prometheus.sh
chmod +x /tmp/prometheus.sh
/tmp/prometheus.sh

wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/docker.sh -O /tmp/docker.sh
chmod +x /tmp/docker.sh
/tmp/docker.sh

wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/k8s%20master.sh -O /tmp/k8s-master.sh
chmod +x /tmp/k8s-master.sh
/tmp/k8s-master.sh

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
set -x  # Enable debug and exit on error

# Download and run ansible node setup
wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/setup-ansible-node.sh -O /tmp/setup-ansible-node.sh
chmod +x /tmp/setup-ansible-node.sh
/tmp/setup-ansible-node.sh

# Download and run prometheus setup
wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/prometheus.sh -O /tmp/prometheus.sh
chmod +x /tmp/prometheus.sh
/tmp/prometheus.sh

# Download and run k8s node setup
wget -q https://github.com/ashwinr200/Finance/raw/refs/heads/dev/k8s-node.sh -O /tmp/k8s-node.sh
chmod +x /tmp/k8s-node.sh
/tmp/k8s-node.sh


  EOF
}
