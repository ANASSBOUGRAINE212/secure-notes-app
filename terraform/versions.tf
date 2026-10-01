terraform {
  # Requiring Terraform 1.5+ keeps this configuration's syntax supported.
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # With no backend block, Terraform stores state locally in this directory.
}

