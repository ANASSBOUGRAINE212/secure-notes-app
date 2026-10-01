# Settings for the MiniStack deployment.

variable "region" {
  description = "AWS region (used by MiniStack for compatibility)"
  type        = string
  default     = "us-east-1"
}

variable "ministack_endpoint" {
  description = "MiniStack API endpoint (e.g., http://localhost:4566 for LocalStack, or MiniStack-specific endpoint)"
  type        = string
  default     = "http://localhost:4566"
}

variable "ministack_access_key" {
  description = "Access key for MiniStack (dummy value, not real AWS credentials)"
  type        = string
  default     = "test"
  sensitive   = true
}

variable "ministack_secret_key" {
  description = "Secret key for MiniStack (dummy value, not real AWS credentials)"
  type        = string
  default     = "test"
  sensitive   = true
}

# Project

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "secure-notes"
}

variable "environment" {
  description = "Environment name (local, dev, staging, production)"
  type        = string
  default     = "local"

  validation {
    condition     = contains(["local", "dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: local, dev, staging, production"
  }
}

# Network

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block"
  }
}

variable "availability_zone" {
  description = "Availability zone for resources (single-AZ deployment for local environment)"
  type        = string
  default     = "us-east-1a"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into instances"
  type        = string
  default     = "0.0.0.0/0"
}

# Kubernetes nodes

variable "kubernetes_control_plane_count" {
  description = "Number of Kubernetes control plane nodes (1 for single-master, 3+ for HA)"
  type        = number
  default     = 1

  validation {
    condition     = var.kubernetes_control_plane_count >= 0 && var.kubernetes_control_plane_count <= 5
    error_message = "Control plane count must be between 0 and 5"
  }
}

variable "kubernetes_node_count" {
  description = "Number of Kubernetes worker nodes"
  type        = number
  default     = 2

  validation {
    condition     = var.kubernetes_node_count >= 0 && var.kubernetes_node_count <= 10
    error_message = "Worker node count must be between 0 and 10"
  }
}

# Instance sizes and disks

variable "instance_ami" {
  description = "AMI ID for EC2 instances (should be Ubuntu 22.04 LTS or similar)"
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Placeholder - adjust for your MiniStack environment
}

variable "control_plane_instance_type" {
  description = "Instance type for Kubernetes control plane nodes"
  type        = string
  default     = "t3.medium" # 2 vCPU, 4 GB RAM - minimum for control plane
}

variable "worker_instance_type" {
  description = "Instance type for Kubernetes worker nodes"
  type        = string
  default     = "t3.small" # 2 vCPU, 2 GB RAM - suitable for worker nodes
}

variable "control_plane_volume_size" {
  description = "Root volume size in GB for control plane nodes"
  type        = number
  default     = 30
}

variable "worker_volume_size" {
  description = "Root volume size in GB for worker nodes"
  type        = number
  default     = 20
}

# SSH access

variable "ssh_public_key" {
  description = "SSH public key content for accessing EC2 instances (not the file path)"
  type        = string

  validation {
    condition     = length(var.ssh_public_key) > 0
    error_message = "SSH public key must be provided"
  }
}
