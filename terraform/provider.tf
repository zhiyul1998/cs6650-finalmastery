# Specify where to find the AWS & Docker providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.7.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.0"
    }
  }
}

# Configure AWS credentials & region
provider "aws" {
  region = var.aws_region
  
  # LocalStack endpoint configuration
  dynamic "endpoints" {
    for_each = var.deployment_target == "localstack" ? [1] : []
    content {
      ec2            = var.localstack_endpoint
      ecs            = var.localstack_endpoint
      ecr            = var.localstack_endpoint
      iam            = var.localstack_endpoint
      logs           = var.localstack_endpoint
      sts            = var.localstack_endpoint
    }
  }
  
  # Skip credential validation for LocalStack
  skip_credentials_validation = var.deployment_target == "localstack"
  skip_metadata_api_check     = var.deployment_target == "localstack"
  skip_region_validation      = var.deployment_target == "localstack"
  
  # Use dummy credentials for LocalStack
  access_key = var.deployment_target == "localstack" ? "test" : null
  secret_key = var.deployment_target == "localstack" ? "test" : null
}

# Fetch an ECR auth token so Terraform's Docker provider can log in (only for AWS)
# LocalStack ECR returns empty auth data which crashes the provider, so we skip it
data "aws_ecr_authorization_token" "registry" {
  count = var.deployment_target == "aws" ? 1 : 0
}

# Configure Docker provider to authenticate against ECR
provider "docker" {
  # AWS ECR authentication
  dynamic "registry_auth" {
    for_each = var.deployment_target == "aws" ? [1] : []
    content {
      address  = replace(data.aws_ecr_authorization_token.registry[0].proxy_endpoint, "https://", "")
      username = data.aws_ecr_authorization_token.registry[0].user_name
      password = data.aws_ecr_authorization_token.registry[0].password
    }
  }
  
  # For LocalStack ECR, we configure without fetching auth token
  # LocalStack ECR may not require authentication, or authentication is handled differently
  dynamic "registry_auth" {
    for_each = var.deployment_target == "localstack" ? [1] : []
    content {
      # LocalStack ECR registry format
      address  = "000000000000.dkr.ecr.${var.aws_region}.localhost.localstack.cloud:4566"
      # Try with empty credentials - LocalStack might not require auth
      username = ""
      password = ""
    }
  }
}