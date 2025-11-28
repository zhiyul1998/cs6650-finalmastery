#!/bin/bash

# Start LocalStack Pro with authentication

set -e

LOCALSTACK_AUTH_TOKEN="${LOCALSTACK_AUTH_TOKEN:-ls-vUTegobo-yuda-cUDi-2732-QeloFagO10b9}"
LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
SERVICES="${SERVICES:-ec2,ecs,ecr,iam,logs,sts}"

echo "=== Starting LocalStack Pro ==="
echo "Endpoint: $LOCALSTACK_ENDPOINT"
echo "Services: $SERVICES"
echo ""

# Check if Docker is running
if ! docker ps &> /dev/null; then
    echo "❌ Error: Docker is not running"
    exit 1
fi

# Stop any existing LocalStack containers
echo "Stopping any existing LocalStack containers..."
echo "Checking for containers using port 4566..."

# Find and stop containers using port 4566
EXISTING_CONTAINERS=$(docker ps --filter "publish=4566" -q)
if [ ! -z "$EXISTING_CONTAINERS" ]; then
    echo "Found containers using port 4566, stopping them..."
    docker stop $EXISTING_CONTAINERS 2>/dev/null || true
    docker rm $EXISTING_CONTAINERS 2>/dev/null || true
fi

# Also stop/remove localstack-pro if it exists
docker stop localstack-pro 2>/dev/null || true
docker rm localstack-pro 2>/dev/null || true

# Stop any other LocalStack containers
docker ps -a --filter "name=localstack" --format "{{.Names}}" | while read name; do
    if [ ! -z "$name" ]; then
        echo "Stopping container: $name"
        docker stop "$name" 2>/dev/null || true
        docker rm "$name" 2>/dev/null || true
    fi
done

# Start LocalStack Pro
echo "Starting LocalStack Pro..."
docker run -d \
  --name localstack-pro \
  -p 4566:4566 \
  -p 4571:4571 \
  -e LOCALSTACK_AUTH_TOKEN="$LOCALSTACK_AUTH_TOKEN" \
  -e SERVICES="$SERVICES" \
  -e DEBUG=1 \
  -e DATA_DIR=/tmp/localstack/data \
  -v "/var/run/docker.sock:/var/run/docker.sock" \
  localstack/localstack-pro

echo ""
echo "⏳ Waiting for LocalStack to be ready..."
sleep 5

# Check if LocalStack is healthy
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -s http://localhost:4566/_localstack/health | grep -q '"ecs": "available"'; then
        echo "✅ LocalStack Pro is ready!"
        echo ""
        echo "Checking service availability..."
        curl -s http://localhost:4566/_localstack/health | jq '.' || echo "Install jq for formatted output: brew install jq"
        break
    fi
    attempt=$((attempt + 1))
    echo "  Waiting... ($attempt/$max_attempts)"
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "⚠️  LocalStack may still be starting. Check logs with:"
    echo "   docker logs localstack-pro"
fi

echo ""
echo "LocalStack Pro is running!"
echo "Stop it with: docker stop localstack-pro"
echo "View logs with: docker logs -f localstack-pro"

