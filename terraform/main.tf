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

 root_block_device {
    volume_size = 30            # Increase to 30 GB
    volume_type = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "${var.env}-Master"
    Role = "master"
  }


}
resource "aws_instance" "node" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.selected.ids[0]
  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = var.key_name
  associate_public_ip_address = true

 root_block_device {
    volume_size = 30            # Increase to 30 GB
    volume_type = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "${var.env}-Node"
    Role = "node"
  }



}
