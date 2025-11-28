#!/bin/bash

# Quick deployment script for LocalStack

set -e

echo "=== Deploying to LocalStack Pro ==="
echo ""

# Check if LocalStack is running
if ! curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    echo "❌ LocalStack is not running!"
    echo "Starting LocalStack Pro..."
    ./start-localstack-pro.sh
    echo ""
    echo "Waiting 10 seconds for LocalStack to be ready..."
    sleep 10
fi

# Check if ECS is available
if curl -s http://localhost:4566/_localstack/health | grep -q '"ecs": "available"'; then
    echo "✅ LocalStack Pro with ECS/ECR is ready"
else
    echo "⚠️  Warning: ECS may not be available. Continuing anyway..."
fi

echo ""
echo "Using Terraform workspace to isolate LocalStack deployment..."
echo ""

# Use workspace to separate from AWS state
terraform workspace select localstack 2>/dev/null || terraform workspace new localstack

echo ""
echo "Deploying infrastructure to LocalStack..."
echo ""

terraform apply -var="deployment_target=localstack" \
                -var="localstack_endpoint=http://localhost:4566" \
                -auto-approve

echo ""
echo "✅ Deployment complete!"
echo ""
echo "To test your API, find the service endpoint and run:"
echo "  curl http://localhost:8080/v1/products/1"
echo ""
echo "To view logs:"
echo "  docker logs localstack-pro"
echo ""
echo "To destroy:"
echo "  terraform destroy -var=\"deployment_target=localstack\" -auto-approve"

