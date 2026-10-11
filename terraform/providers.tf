terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

}

# MiniStack uses the AWS provider with a local API endpoint.
provider "aws" {
  region = var.region

  endpoints {
    ec2 = var.ministack_endpoint
    s3  = var.ministack_endpoint
    iam = var.ministack_endpoint
  }

  access_key                  = var.ministack_access_key
  secret_key                  = var.ministack_secret_key
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Platform    = "MiniStack"
    }
  }
}
