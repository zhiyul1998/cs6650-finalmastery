# Deployment environment: "aws" or "localstack"
variable "deployment_target" {
  type        = string
  default     = "aws"
  description = "Deployment target: 'aws' for AWS Learner Lab, 'localstack' for LocalStack"
  validation {
    condition     = contains(["aws", "localstack"], var.deployment_target)
    error_message = "deployment_target must be either 'aws' or 'localstack'."
  }
}

# LocalStack endpoint (only used when deployment_target = "localstack")
variable "localstack_endpoint" {
  type        = string
  default     = "http://localhost:4566"
  description = "LocalStack endpoint URL"
}

# Region to deploy into
variable "aws_region" {
  type    = string
  default = "us-west-2"
}

# ECR & ECS settings
variable "ecr_repository_name" {
  type    = string
  default = "ecr_service"
}

variable "service_name" {
  type    = string
  default = "CS6650L2"
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "ecs_count" {
  type    = number
  default = 1
}

# How long to keep logs
variable "log_retention_days" {
  type    = number
  default = 7
}
