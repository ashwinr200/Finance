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
subnet_id = data.aws_subnets.selected.ids[0]

  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${var.env}_master"
    Role = "master"
  }
user_data = <<-EOF
              #!/bin/bash
              useradd -m -s /bin/bash ansadmin
              echo 'ansadmin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
              mkdir -p /home/ansadmin/.ssh
              cp /home/ubuntu/.ssh/authorized_keys /home/ansadmin/.ssh/authorized_keys
              chown -R ansadmin:ansadmin /home/ansadmin/.ssh
              chmod 700 /home/ansadmin/.ssh
              chmod 600 /home/ansadmin/.ssh/authorized_keys
              apt update
              apt install -y ansible
            EOF


}

resource "aws_instance" "node" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
 subnet_id = data.aws_subnets.selected.ids[0]

  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${var.env}_node"
    Role = "node"
  }
}
