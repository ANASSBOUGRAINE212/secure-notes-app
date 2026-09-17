# GENERAL VARIABLES

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "secure-notes"
}

variable "environment" {
  description = "Environment (local, dev, staging, production)"
  type        = string
  default     = "local"
}

variable "use_local_emulator" {
  description = "Set to true for MiniStack, false for real AWS"
  type        = bool
  default     = true
}

# VPC VARIABLES

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# EKS VARIABLES

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "secure-notes-eks"
}

variable "eks_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.31"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 4
}

# RDS VARIABLES

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "auth_db_username" {
  description = "Username for auth database"
  type        = string
  default     = "auth_admin"
  sensitive   = true
}

variable "auth_db_password" {
  description = "Password for auth database"
  type        = string
  sensitive   = true
}

variable "notes_db_username" {
  description = "Username for notes database"
  type        = string
  default     = "notes_admin"
  sensitive   = true
}

variable "notes_db_password" {
  description = "Password for notes database"
  type        = string
  sensitive   = true
}
