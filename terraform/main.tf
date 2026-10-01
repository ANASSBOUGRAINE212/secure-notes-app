# MiniStack network and VM resources. Ansible configures the VMs afterward.

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Network

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

# The subnet gives the nodes IP addresses in the VPC. `count` creates it only
# when worker nodes are requested; `[0]` below refers to this first subnet.
resource "aws_subnet" "public" {
  count = var.kubernetes_node_count > 0 ? 1 : 0

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-subnet"
    Type = "public"
  })
}

# This route sends traffic outside the VPC through the internet gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = var.kubernetes_node_count > 0 ? 1 : 0

  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public.id
}

# Security groups

# Security groups are network firewalls. These rules allow the control-plane
# ports needed by Kubernetes; internal cluster traffic is allowed from the VPC.
resource "aws_security_group" "k8s_control_plane" {
  name        = "${var.project_name}-k8s-control-plane-sg"
  description = "Security group for Kubernetes control plane node"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Kubernetes API server
  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # etcd server client API
  ingress {
    description = "etcd"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Kubelet API
  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # kube-scheduler
  ingress {
    description = "kube-scheduler"
    from_port   = 10259
    to_port     = 10259
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # kube-controller-manager
  ingress {
    description = "kube-controller-manager"
    from_port   = 10257
    to_port     = 10257
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # HTTP/HTTPS for ingress
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all traffic within the VPC
  ingress {
    description = "Internal VPC traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-k8s-control-plane-sg"
  })
}

# Worker machines need the kubelet port, NodePort range, and internal traffic.
resource "aws_security_group" "k8s_workers" {
  name        = "${var.project_name}-k8s-workers-sg"
  description = "Security group for Kubernetes worker nodes"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Kubelet API
  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # NodePort Services
  ingress {
    description = "NodePort Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all traffic within the VPC
  ingress {
    description = "Internal VPC traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-k8s-workers-sg"
  })
}

# Register the public SSH key used to connect to the VMs.
resource "aws_key_pair" "k8s_nodes" {
  key_name   = "${var.project_name}-k8s-key"
  public_key = var.ssh_public_key

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-k8s-key"
  })
}

# Control-plane VMs. Adding one to `count.index` makes names start at 1.

resource "aws_instance" "k8s_control_plane" {
  count = var.kubernetes_control_plane_count

  ami           = var.instance_ami
  instance_type = var.control_plane_instance_type
  key_name      = aws_key_pair.k8s_nodes.key_name

  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.k8s_control_plane.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.control_plane_volume_size
    volume_type           = "gp2"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = <<-EOF
              #!/bin/bash
              # Basic setup - Ansible will handle the rest
              hostnamectl set-hostname k8s-control-plane-${count.index + 1}
              EOF

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-k8s-control-plane-${count.index + 1}"
    Role = "control-plane"
    Type = "kubernetes"
  })
}

# Worker VMs.

resource "aws_instance" "k8s_workers" {
  count = var.kubernetes_node_count

  ami           = var.instance_ami
  instance_type = var.worker_instance_type
  key_name      = aws_key_pair.k8s_nodes.key_name

  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.k8s_workers.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.worker_volume_size
    volume_type           = "gp2"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = <<-EOF
              #!/bin/bash
              # Basic setup - Ansible will handle the rest
              hostnamectl set-hostname k8s-worker-${count.index + 1}
              EOF

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-k8s-worker-${count.index + 1}"
    Role = "worker"
    Type = "kubernetes"
  })
}
