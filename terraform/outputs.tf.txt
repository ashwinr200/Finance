output "master_private_ip_${var.env}" {
  value = aws_instance.master.private_ip
}

output "master_public_ip_${var.env}" {
  value = aws_instance.master.public_ip
}

output "node_private_ip_${var.env}" {
  value = aws_instance.node.private_ip
}

output "node_public_ip_${var.env}" {
  value = aws_instance.node.public_ip
}
