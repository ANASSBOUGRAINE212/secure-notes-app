# Using the AWS provider's resource types with the local MiniStack emulator.
provider "aws" {
  region = var.region

  # Sending supported AWS API requests to MiniStack.
  endpoints {
    ec2 = var.ministack_endpoint
    s3  = var.ministack_endpoint
    iam = var.ministack_endpoint
  }

  # Using MiniStack's dummy credentials, not AWS keys.
  access_key                  = var.ministack_access_key
  secret_key                  = var.ministack_secret_key
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # Applying these tags to every resource.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Platform    = "MiniStack"
    }
  }
}
