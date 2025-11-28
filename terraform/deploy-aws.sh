#!/bin/bash

# AWS Deployment Script
# This script helps deploy the infrastructure to AWS Learner Lab

set -e  # Exit on error

echo "=== AWS Learner Lab Deployment Script ==="
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Error: AWS CLI is not configured or credentials are invalid"
    echo "   Please run: aws configure"
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Error: Terraform is not installed"
    exit 1
fi

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed"
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Apply with AWS configuration (default)
echo ""
echo "Deploying to AWS Learner Lab..."
echo ""

terraform apply -var="deployment_target=aws" -auto-approve

echo ""
echo "✅ Deployment complete!"
echo ""
echo "To get the public IP address:"
echo "  aws ec2 describe-network-interfaces \\"
echo "    --network-interface-ids \$("
echo "      aws ecs describe-tasks \\"
echo "        --cluster \$(terraform output -raw ecs_cluster_name) \\"
echo "        --tasks \$("
echo "          aws ecs list-tasks \\"
echo "            --cluster \$(terraform output -raw ecs_cluster_name) \\"
echo "            --service-name \$(terraform output -raw ecs_service_name) \\"
echo "            --query 'taskArns[0]' --output text"
echo "        ) \\"
echo "        --query \"tasks[0].attachments[0].details[?name=='networkInterfaceId'].value\" \\"
echo "        --output text"
echo "    ) \\"
echo "    --query 'NetworkInterfaces[0].Association.PublicIp' \\"
echo "    --output text"
echo ""
echo "To test the API:"
echo "  curl http://<PUBLIC_IP>:8080/v1/products/1"
echo ""
echo "To destroy the infrastructure:"
echo "  terraform destroy -var=\"deployment_target=aws\" -auto-approve"

