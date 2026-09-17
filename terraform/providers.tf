terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Backend for remote state (uncomment for production with real AWS)
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "secure-notes/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  # MiniStack endpoints (only used when use_local_emulator = true)
  dynamic "endpoints" {
    for_each = var.use_local_emulator ? [1] : []
    content {
      ecr = "http://localhost:4566"
      s3  = "http://localhost:4566"
      iam = "http://localhost:4566"
      sts = "http://localhost:4566"
      eks = "http://localhost:4566"
      rds = "http://localhost:4566"
      ec2 = "http://localhost:4566"
    }
  }

  access_key                  = var.use_local_emulator ? "test" : null
  secret_key                  = var.use_local_emulator ? "test" : null
  skip_credentials_validation = var.use_local_emulator
  skip_metadata_api_check     = var.use_local_emulator
  skip_requesting_account_id  = var.use_local_emulator

  # Default tags applied to all resources
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
