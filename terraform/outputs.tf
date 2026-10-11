# Network

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = length(aws_subnet.public) > 0 ? aws_subnet.public[0].id : null
}

# Control plane

output "control_plane_instance_ids" {
  description = "Instance IDs of Kubernetes control plane nodes"
  value       = aws_instance.k8s_control_plane[*].id
}

output "control_plane_public_ips" {
  description = "Public IP addresses of Kubernetes control plane nodes"
  value       = aws_instance.k8s_control_plane[*].public_ip
}

output "control_plane_private_ips" {
  description = "Private IP addresses of Kubernetes control plane nodes"
  value       = aws_instance.k8s_control_plane[*].private_ip
}

output "control_plane_public_dns" {
  description = "Public DNS names of Kubernetes control plane nodes"
  value       = aws_instance.k8s_control_plane[*].public_dns
}

# Workers

output "worker_instance_ids" {
  description = "Instance IDs of Kubernetes worker nodes"
  value       = aws_instance.k8s_workers[*].id
}

output "worker_public_ips" {
  description = "Public IP addresses of Kubernetes worker nodes"
  value       = aws_instance.k8s_workers[*].public_ip
}

output "worker_private_ips" {
  description = "Private IP addresses of Kubernetes worker nodes"
  value       = aws_instance.k8s_workers[*].private_ip
}

output "worker_public_dns" {
  description = "Public DNS names of Kubernetes worker nodes"
  value       = aws_instance.k8s_workers[*].public_dns
}

output "ssh_key_name" {
  description = "Name of the SSH key pair used for instances"
  value       = aws_key_pair.k8s_nodes.key_name
}

# Security groups
output "control_plane_security_group_id" {
  description = "Security group ID for control plane nodes"
  value       = aws_security_group.k8s_control_plane.id
}

output "worker_security_group_id" {
  description = "Security group ID for worker nodes"
  value       = aws_security_group.k8s_workers.id
}

# Inventory lines for Ansible
output "ansible_inventory_control_plane" {
  description = "Ansible inventory entries for control plane nodes (copy to inventory.ini)"
  value = join("\n", [
    for idx, instance in aws_instance.k8s_control_plane :
    "${instance.tags["Name"]} ansible_host=${instance.public_ip} ansible_user=ubuntu private_ip=${instance.private_ip}"
  ])
}

output "ansible_inventory_workers" {
  description = "Ansible inventory entries for worker nodes (copy to inventory.ini)"
  value = join("\n", [
    for idx, instance in aws_instance.k8s_workers :
    "${instance.tags["Name"]} ansible_host=${instance.public_ip} ansible_user=ubuntu private_ip=${instance.private_ip}"
  ])
}

# SSH commands and cluster summary
output "ssh_connection_commands" {
  description = "SSH commands to connect to each node"
  value = merge(
    {
      for idx, instance in aws_instance.k8s_control_plane :
      "control-plane-${idx + 1}" => "ssh -i ~/.ssh/id_rsa ubuntu@${instance.public_ip}"
    },
    {
      for idx, instance in aws_instance.k8s_workers :
      "worker-${idx + 1}" => "ssh -i ~/.ssh/id_rsa ubuntu@${instance.public_ip}"
    }
  )
}

output "cluster_summary" {
  description = "Summary of the provisioned Kubernetes cluster infrastructure"
  value = {
    control_plane_count = length(aws_instance.k8s_control_plane)
    worker_count        = length(aws_instance.k8s_workers)
    total_nodes         = length(aws_instance.k8s_control_plane) + length(aws_instance.k8s_workers)
    vpc_cidr            = aws_vpc.main.cidr_block
    control_plane_ips   = aws_instance.k8s_control_plane[*].public_ip
    worker_ips          = aws_instance.k8s_workers[*].public_ip
  }
}
