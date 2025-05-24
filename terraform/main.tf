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
wget https://github.com/ashwinr200/Finance/raw/refs/heads/dev/setup-ansible-master.sh -O /tmp/setup-ansible-master.sh
    chmod +x /tmp/setup-ansible-master.sh
    /tmp/setup-ansible-master.sh
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
wget https://github.com/ashwinr200/Finance/raw/refs/heads/dev/setup-ansible-node.sh -O /tmp/setup-ansible-node.sh
    chmod +x /tmp/setup-ansible-node.sh
    /tmp/setup-ansible-node.sh
EOF
}
