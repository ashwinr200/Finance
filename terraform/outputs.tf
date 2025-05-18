output "node_public_ip" {
  value       = aws_instance.node.public_ip
  description = "Public IP of node in environment ${var.env}"
}

output "node_private_ip" {
  value       = aws_instance.node.private_ip
  description = "Private IP of node in environment ${var.env}"
}

output "master_public_ip" {
  value       = aws_instance.master.public_ip
  description = "Public IP of master in environment ${var.env}"
}

output "master_private_ip" {
  value       = aws_instance.master.private_ip
  description = "Private IP of master in environment ${var.env}"
}
