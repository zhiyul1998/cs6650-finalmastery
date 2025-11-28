#!/bin/bash

# Get the LocalStack ECS service endpoint

set -e

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-west-2

CLUSTER_NAME="${1:-CS6650L2-cluster}"
SERVICE_NAME="${2:-CS6650L2}"

echo "Finding endpoint for service: $SERVICE_NAME in cluster: $CLUSTER_NAME"
echo ""

# Get the task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --endpoint-url=http://localhost:4566 \
  --query 'taskArns[0]' \
  --output text 2>/dev/null)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" == "None" ]; then
    echo "❌ No tasks found for service $SERVICE_NAME"
    exit 1
fi

echo "Task ARN: $TASK_ARN"
echo ""

# Find the Docker container port mapping
CONTAINER_NAME=$(docker ps --filter "label=service=$SERVICE_NAME" --format "{{.Names}}" | head -1)

if [ -z "$CONTAINER_NAME" ]; then
    echo "❌ Container not found"
    exit 1
fi

# Extract the port mapping
PORT_MAPPING=$(docker port "$CONTAINER_NAME" 8080/tcp 2>/dev/null | cut -d: -f2)

if [ -z "$PORT_MAPPING" ]; then
    # Try alternative method
    PORT_MAPPING=$(docker ps --filter "name=$CONTAINER_NAME" --format "{{.Ports}}" | grep -oP '0.0.0.0:\K[0-9]+' | head -1)
fi

if [ -z "$PORT_MAPPING" ]; then
    echo "❌ Could not find port mapping"
    echo "Container: $CONTAINER_NAME"
    docker ps --filter "name=$CONTAINER_NAME" --format "{{.Ports}}"
    exit 1
fi

echo "✅ Service is running!"
echo ""
echo "API Endpoint: http://localhost:$PORT_MAPPING"
echo ""
echo "Test commands:"
echo "  curl http://localhost:$PORT_MAPPING/v1/products/1"
echo "  curl -X POST http://localhost:$PORT_MAPPING/v1/products/1/details \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d '{\"id\":1,\"name\":\"Updated T-Shirt\",\"price\":13.99,\"description\":\"New color\"}'"

