# Wire together four focused modules: network, ecr, logging, ecs.

module "network" {
  source         = "./modules/network"
  service_name   = var.service_name
  container_port = var.container_port
}

module "ecr" {
  source          = "./modules/ecr"
  repository_name = var.ecr_repository_name
}

module "logging" {
  source            = "./modules/logging"
  service_name      = var.service_name
  retention_in_days = var.log_retention_days
}

# IAM Role for ECS tasks - create for LocalStack, reuse existing for AWS
data "aws_iam_role" "lab_role" {
  count = var.deployment_target == "aws" ? 1 : 0
  name  = "LabRole"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  count = var.deployment_target == "localstack" ? 1 : 0
  name  = "${var.service_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  count      = var.deployment_target == "localstack" ? 1 : 0
  role       = aws_iam_role.ecs_task_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  count = var.deployment_target == "localstack" ? 1 : 0
  name  = "${var.service_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

locals {
  execution_role_arn = var.deployment_target == "localstack" ? aws_iam_role.ecs_task_execution_role[0].arn : data.aws_iam_role.lab_role[0].arn
  
  task_role_arn = var.deployment_target == "localstack" ? aws_iam_role.ecs_task_role[0].arn : data.aws_iam_role.lab_role[0].arn
}

module "ecs" {
  source             = "./modules/ecs"
  service_name       = var.service_name
  image              = "${module.ecr.repository_url}:latest"
  container_port     = var.container_port
  subnet_ids         = module.network.subnet_ids
  security_group_ids = [module.network.security_group_id]
  execution_role_arn = local.execution_role_arn
  task_role_arn      = local.task_role_arn
  log_group_name     = module.logging.log_group_name
  ecs_count          = var.ecs_count
  region             = var.aws_region
}


// Build & push the app image into ECR
resource "docker_image" "app" {
  # Use the URL from the ecr module, and tag it "latest"
  name = "${module.ecr.repository_url}:latest"

  build {
    # relative path from terraform/ → src/
    context = "../src"
    # Dockerfile defaults to "Dockerfile" in that context
  }
}

resource "docker_registry_image" "app" {
  # this will push :latest → ECR
  name = docker_image.app.name
  
  # For LocalStack, we need to ensure Docker is authenticated
  # LocalStack ECR may require manual Docker login first
  # If this fails, you may need to run:
  # docker login localhost -u test -p test
  # or extract credentials from: aws ecr get-login-password --endpoint-url=http://localhost:4566
}
