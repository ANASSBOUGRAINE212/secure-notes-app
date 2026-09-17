# ECR OUTPUTS

output "ecr_repository_urls" {
  description = "ECR repository URLs for each service"
  value       = { for name, repo in aws_ecr_repository.service : name => repo.repository_url }
}

# S3 OUTPUTS


output "artifacts_bucket_name" {
  description = "Name of the S3 artifacts bucket"
  value       = aws_s3_bucket.artifacts.bucket
}

output "artifacts_bucket_arn" {
  description = "ARN of the S3 artifacts bucket"
  value       = aws_s3_bucket.artifacts.arn
}


# VPC OUTPUTS

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

# EKS OUTPUTS

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "eks_node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.main.id
}

output "eks_kubectl_config" {
  description = "kubectl config command to connect to the cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

# RDS OUTPUTS


output "auth_db_endpoint" {
  description = "Endpoint for auth service database"
  value       = aws_db_instance.auth.endpoint
}

output "auth_db_address" {
  description = "Address for auth service database"
  value       = aws_db_instance.auth.address
}

output "auth_db_name" {
  description = "Database name for auth service"
  value       = aws_db_instance.auth.db_name
}

output "notes_db_endpoint" {
  description = "Endpoint for notes service database"
  value       = aws_db_instance.notes.endpoint
}

output "notes_db_address" {
  description = "Address for notes service database"
  value       = aws_db_instance.notes.address
}

output "notes_db_name" {
  description = "Database name for notes service"
  value       = aws_db_instance.notes.db_name
}

# CONNECTION STRINGS (for Kubernetes secrets)

output "auth_db_connection_string" {
  description = "PostgreSQL connection string for auth service (format for DATABASE_URL)"
  value       = "postgresql://${var.auth_db_username}:${var.auth_db_password}@${aws_db_instance.auth.address}:5432/${aws_db_instance.auth.db_name}"
  sensitive   = true
}

output "notes_db_connection_string" {
  description = "PostgreSQL connection string for notes service (format for DATABASE_URL)"
  value       = "postgresql://${var.notes_db_username}:${var.notes_db_password}@${aws_db_instance.notes.address}:5432/${aws_db_instance.notes.db_name}"
  sensitive   = true
}
