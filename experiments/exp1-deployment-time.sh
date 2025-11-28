#!/bin/bash

# Experiment 1: Deployment Time & Infrastructure Setup
# Measures time to deploy and make infrastructure ready

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RESULTS_DIR="$1"
if [ -z "$RESULTS_DIR" ]; then
    echo "Usage: $0 <results_directory>"
    exit 1
fi

# Make results path absolute if relative
if [[ ! "$RESULTS_DIR" = /* ]]; then
    RESULTS_DIR="${PROJECT_ROOT}/${RESULTS_DIR}"
fi

# Create results directory if it doesn't exist
mkdir -p "${RESULTS_DIR}"

OUTPUT_FILE="${RESULTS_DIR}/exp1-deployment-time.csv"

echo "═══════════════════════════════════════════════════════════════"
echo "Experiment 1: Deployment Time & Infrastructure Setup"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Results will be saved to: ${OUTPUT_FILE}"
echo ""

# Create CSV header
echo "Environment,Iteration,DestroyTime,DeployTime,TimeToFirstRequest,TotalDeployTime,FullCycleTime" > "${OUTPUT_FILE}"

# Function to destroy AWS deployment (returns destroy time in seconds)
destroy_aws_deployment() {
    echo "  Destroying AWS deployment..." >&2
    cd "${PROJECT_ROOT}/infra/CS6650_2b_demo/terraform"
    
    # Check if workspace exists, if not return 0
    if ! terraform workspace select default 2>/dev/null; then
        echo "0"
        return 0
    fi
    
    DESTROY_START=$(date +%s.%N)
    terraform destroy -var="deployment_target=aws" -auto-approve > /tmp/aws_destroy.log 2>&1
    DESTROY_END=$(date +%s.%N)
    DESTROY_DURATION=$(echo "scale=2; $DESTROY_END - $DESTROY_START" | bc 2>/dev/null || echo "0")
    
    # Validate the result is a number
    if ! echo "$DESTROY_DURATION" | grep -qE '^[0-9]+\.?[0-9]*$'; then
        DESTROY_DURATION="0"
    fi
    
    echo "  ✅ AWS deployment destroyed (took ${DESTROY_DURATION}s)" >&2
    echo "$DESTROY_DURATION"  # Return destroy duration to stdout
}

# Function to measure AWS deployment time
measure_aws_deployment() {
    local iteration=$1
    local should_destroy=$2  # "true" or "false"
    
    echo "Measuring AWS deployment (iteration $iteration)..."
    
    cd "${PROJECT_ROOT}/infra/CS6650_2b_demo/terraform"
    
    # Switch to AWS workspace
    terraform workspace select default 2>/dev/null || terraform workspace new default
    
    # Destroy if needed (before first iteration or if requested)
    DESTROY_DURATION=0
    if [ "$should_destroy" == "true" ]; then
        DESTROY_DURATION=$(destroy_aws_deployment | tr -d '[:space:]')
        # Ensure it's a valid number, default to 0 if not
        if ! echo "$DESTROY_DURATION" | grep -qE '^[0-9]+\.?[0-9]*$'; then
            DESTROY_DURATION="0"
        fi
        sleep 5  # Brief pause after destroy
    fi
    
    # Start timing for deployment
    START_TIME=$(date +%s.%N)
    
    # Deploy fresh
    echo "  Deploying to AWS..."
    terraform apply -var="deployment_target=aws" -auto-approve > /tmp/aws_deploy_${iteration}.log 2>&1
    
    DEPLOY_TIME=$(date +%s.%N)
    DEPLOY_DURATION=$(echo "scale=2; $DEPLOY_TIME - $START_TIME" | bc 2>/dev/null || echo "0")
    
    # Get endpoint
    echo "  Getting AWS endpoint..."
    
    # Wait for task to be running first
    CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
    SERVICE_NAME=$(terraform output -raw ecs_service_name)
    
    echo "  Waiting for ECS task to start..."
    TASK_WAIT=0
    TASK_ARN=""
    while [ $TASK_WAIT -lt 180 ]; do
        TASK_ARN=$(aws ecs list-tasks \
          --cluster "$CLUSTER_NAME" \
          --service-name "$SERVICE_NAME" \
          --query 'taskArns[0]' \
          --output text 2>/dev/null || echo "")
        
        if [ ! -z "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ] && [ ${#TASK_ARN} -gt 30 ]; then
            break
        fi
        sleep 5
        TASK_WAIT=$((TASK_WAIT + 5))
    done
    
    if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" == "None" ]; then
        echo "  ⚠️  Warning: Could not get task ARN, trying alternative method..."
        # Try to get IP directly from service
        AWS_ENDPOINT="http://$(terraform output -raw ecs_cluster_name):8080" || AWS_ENDPOINT=""
    else
        echo "  Task ARN: $TASK_ARN"
        AWS_IP=$(aws ec2 describe-network-interfaces \
          --network-interface-ids $(aws ecs describe-tasks \
            --cluster "$CLUSTER_NAME" \
            --tasks "$TASK_ARN" \
            --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
            --output text 2>/dev/null) \
          --query 'NetworkInterfaces[0].Association.PublicIp' \
          --output text 2>/dev/null || echo "")
        
        if [ -z "$AWS_IP" ] || [ "$AWS_IP" == "None" ]; then
            echo "  ⚠️  Warning: Could not get public IP, will try localhost..."
            AWS_ENDPOINT=""
        else
            AWS_ENDPOINT="http://${AWS_IP}:8080"
            echo "  AWS Endpoint: $AWS_ENDPOINT"
        fi
    fi
    
    # Wait for API to be ready
    echo "  Waiting for API to be ready..."
    
    # If endpoint is not set, try to get it again
    if [ -z "$AWS_ENDPOINT" ]; then
        echo "  Retrying endpoint retrieval..."
        CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
        SERVICE_NAME=$(terraform output -raw ecs_service_name)
        TASK_ARN=$(aws ecs list-tasks \
          --cluster "$CLUSTER_NAME" \
          --service-name "$SERVICE_NAME" \
          --query 'taskArns[0]' \
          --output text 2>/dev/null || echo "")
        
        if [ ! -z "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ] && [ ${#TASK_ARN} -gt 30 ]; then
            AWS_IP=$(aws ec2 describe-network-interfaces \
              --network-interface-ids $(aws ecs describe-tasks \
                --cluster "$CLUSTER_NAME" \
                --tasks "$TASK_ARN" \
                --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
                --output text 2>/dev/null) \
              --query 'NetworkInterfaces[0].Association.PublicIp' \
              --output text 2>/dev/null || echo "")
            
            if [ ! -z "$AWS_IP" ] && [ "$AWS_IP" != "None" ]; then
                AWS_ENDPOINT="http://${AWS_IP}:8080"
                echo "  AWS Endpoint: $AWS_ENDPOINT"
            fi
        fi
    fi
    
    if [ -z "$AWS_ENDPOINT" ]; then
        echo "  ❌ Error: Could not determine AWS endpoint. Skipping API readiness check."
        FIRST_REQUEST_TIME=$(date +%s.%N)
        FIRST_REQUEST_DURATION=$(echo "scale=2; $FIRST_REQUEST_TIME - $START_TIME" | bc 2>/dev/null || echo "0")
    else
        MAX_WAIT=300  # 5 minutes
        WAITED=0
        while [ $WAITED -lt $MAX_WAIT ]; do
            if curl -s -f "${AWS_ENDPOINT}/v1/products/1" > /dev/null 2>&1; then
                break
            fi
            sleep 5
            WAITED=$((WAITED + 5))
            echo "    Waiting... ($WAITED seconds)"
        done
    fi
    
    FIRST_REQUEST_TIME=$(date +%s.%N)
    FIRST_REQUEST_DURATION=$(echo "scale=2; $FIRST_REQUEST_TIME - $START_TIME" | bc 2>/dev/null || echo "0")
    TOTAL_DEPLOY_DURATION=$(echo "scale=2; $FIRST_REQUEST_TIME - $START_TIME" | bc 2>/dev/null || echo "0")
    FULL_CYCLE_DURATION=$(echo "scale=2; $DESTROY_DURATION + $TOTAL_DEPLOY_DURATION" | bc 2>/dev/null || echo "$TOTAL_DEPLOY_DURATION")
    
    # Record results
    echo "AWS,$iteration,$DESTROY_DURATION,$DEPLOY_DURATION,$FIRST_REQUEST_DURATION,$TOTAL_DEPLOY_DURATION,$FULL_CYCLE_DURATION" >> "${OUTPUT_FILE}"
    
    echo "  ✅ AWS deployment complete"
    # Check if destroy duration is greater than 0 using a safer method
    DESTROY_CHECK=$(echo "scale=2; $DESTROY_DURATION > 0" | bc 2>/dev/null)
    if [ "$DESTROY_CHECK" = "1" ]; then
        echo "     Destroy time: ${DESTROY_DURATION}s"
    fi
    echo "     Deploy time: ${DEPLOY_DURATION}s"
    echo "     Time to first request: ${FIRST_REQUEST_DURATION}s"
    if [ "$DESTROY_CHECK" = "1" ]; then
        echo "     Full cycle (destroy + deploy): ${FULL_CYCLE_DURATION}s"
    fi
    
    cd - > /dev/null
}

# Function to destroy LocalStack deployment (returns destroy time in seconds)
destroy_localstack_deployment() {
    echo "  Destroying LocalStack deployment..." >&2
    cd "${PROJECT_ROOT}/infra/CS6650_2b_demo/terraform"
    
    # Check if workspace exists, if not return 0
    if ! terraform workspace select localstack 2>/dev/null; then
        echo "0"
        return 0
    fi
    
    # Stop running containers first
    docker stop $(docker ps --filter "name=ls-ecs" -q) 2>/dev/null || true
    
    DESTROY_START=$(date +%s.%N)
    terraform destroy -var="deployment_target=localstack" \
                      -var="localstack_endpoint=http://localhost:4566" \
                      -auto-approve > /tmp/localstack_destroy.log 2>&1
    DESTROY_END=$(date +%s.%N)
    DESTROY_DURATION=$(echo "scale=2; $DESTROY_END - $DESTROY_START" | bc 2>/dev/null || echo "0")
    
    # Validate the result is a number
    if ! echo "$DESTROY_DURATION" | grep -qE '^[0-9]+\.?[0-9]*$'; then
        DESTROY_DURATION="0"
    fi
    
    echo "  ✅ LocalStack deployment destroyed (took ${DESTROY_DURATION}s)" >&2
    echo "$DESTROY_DURATION"  # Return destroy duration to stdout
}

# Function to measure LocalStack deployment time
measure_localstack_deployment() {
    local iteration=$1
    local should_destroy=$2  # "true" or "false"
    
    echo "Measuring LocalStack deployment (iteration $iteration)..."
    
    cd "${PROJECT_ROOT}/infra/CS6650_2b_demo/terraform"
    
    # Ensure LocalStack is running
    if ! docker ps --filter "name=localstack-pro" --format "{{.Names}}" | grep -q localstack-pro; then
        echo "  Starting LocalStack..."
        ./start-localstack-pro.sh > /dev/null 2>&1
        sleep 10
    fi
    
    # Switch to localstack workspace
    terraform workspace select localstack 2>/dev/null || terraform workspace new localstack
    
    # Destroy if needed (before first iteration or if requested)
    DESTROY_DURATION=0
    if [ "$should_destroy" == "true" ]; then
        DESTROY_DURATION=$(destroy_localstack_deployment 2>&1 | tr -d '[:space:]' || echo "0")
        # Ensure it's a valid number, default to 0 if not
        if ! echo "$DESTROY_DURATION" | grep -qE '^[0-9]+\.?[0-9]*$'; then
            DESTROY_DURATION="0"
        fi
        # Remove any non-numeric characters except decimal point
        DESTROY_DURATION=$(echo "$DESTROY_DURATION" | sed 's/[^0-9.]//g')
        if [ -z "$DESTROY_DURATION" ] || [ "$DESTROY_DURATION" = "." ]; then
            DESTROY_DURATION="0"
        fi
        sleep 2  # Brief pause after destroy
    fi
    
    # Start timing for deployment
    START_TIME=$(date +%s.%N)
    
    # Deploy fresh
    echo "  Deploying to LocalStack..."
    terraform apply -var="deployment_target=localstack" \
                    -var="localstack_endpoint=http://localhost:4566" \
                    -auto-approve > /tmp/localstack_deploy_${iteration}.log 2>&1
    
    DEPLOY_TIME=$(date +%s.%N)
    DEPLOY_DURATION=$(echo "scale=2; $DEPLOY_TIME - $START_TIME" | bc 2>/dev/null || echo "0")
    
    # Get endpoint
    echo "  Getting LocalStack endpoint..."
    LOCALSTACK_PORT=$(./get-localstack-endpoint.sh 2>/dev/null | grep "API Endpoint" | grep -oE '[0-9]+' || echo "8080")
    LOCALSTACK_ENDPOINT="http://localhost:${LOCALSTACK_PORT}"
    
    # Wait for API to be ready
    echo "  Waiting for API to be ready..."
    MAX_WAIT=120  # 2 minutes
    WAITED=0
    while [ $WAITED -lt $MAX_WAIT ]; do
        if curl -s -f "${LOCALSTACK_ENDPOINT}/v1/products/1" > /dev/null 2>&1; then
            break
        fi
        sleep 2
        WAITED=$((WAITED + 2))
    done
    
    FIRST_REQUEST_TIME=$(date +%s.%N)
    FIRST_REQUEST_DURATION=$(echo "scale=2; $FIRST_REQUEST_TIME - $START_TIME" | bc 2>/dev/null || echo "0")
    TOTAL_DEPLOY_DURATION=$(echo "scale=2; $FIRST_REQUEST_TIME - $START_TIME" | bc 2>/dev/null || echo "0")
    FULL_CYCLE_DURATION=$(echo "scale=2; $DESTROY_DURATION + $TOTAL_DEPLOY_DURATION" | bc 2>/dev/null || echo "$TOTAL_DEPLOY_DURATION")
    
    # Record results
    echo "LocalStack,$iteration,$DESTROY_DURATION,$DEPLOY_DURATION,$FIRST_REQUEST_DURATION,$TOTAL_DEPLOY_DURATION,$FULL_CYCLE_DURATION" >> "${OUTPUT_FILE}"
    
    echo "  ✅ LocalStack deployment complete"
    # Check if destroy duration is greater than 0 using a safer method
    DESTROY_CHECK=$(echo "scale=2; $DESTROY_DURATION > 0" | bc 2>/dev/null)
    if [ "$DESTROY_CHECK" = "1" ]; then
        echo "     Destroy time: ${DESTROY_DURATION}s"
    fi
    echo "     Deploy time: ${DEPLOY_DURATION}s"
    echo "     Time to first request: ${FIRST_REQUEST_DURATION}s"
    if [ "$DESTROY_CHECK" = "1" ]; then
        echo "     Full cycle (destroy + deploy): ${FULL_CYCLE_DURATION}s"
    fi
    
    cd - > /dev/null
}

# Run experiments
NUM_ITERATIONS=${NUM_ITERATIONS:-3}
DESTROY_BETWEEN=${DESTROY_BETWEEN:-true}  # Set to "false" to skip destroys (faster but less accurate)

echo "Running $NUM_ITERATIONS iterations for each environment..."
echo "Destroy between iterations: $DESTROY_BETWEEN"
echo ""

# Ask user confirmation before starting
echo "This will deploy and destroy $NUM_ITERATIONS times for each environment."
echo "For AWS: This may incur costs for each deployment cycle."
echo ""
read -p "Continue? (y/n): " continue_choice
if [ "$continue_choice" != "y" ]; then
    echo "Aborted."
    exit 0
fi

for i in $(seq 1 $NUM_ITERATIONS); do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Iteration $i of $NUM_ITERATIONS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Determine if we should destroy (always destroy before first iteration)
    if [ $i -eq 1 ] || [ "$DESTROY_BETWEEN" == "true" ]; then
        SHOULD_DESTROY="true"
    else
        SHOULD_DESTROY="false"
    fi
    
    # Test LocalStack
    measure_localstack_deployment $i "$SHOULD_DESTROY"
    echo ""
    
    # Destroy LocalStack after measurement (unless it's the last iteration and user wants to keep it)
    if [ "$DESTROY_BETWEEN" == "true" ] && [ $i -lt $NUM_ITERATIONS ]; then
        destroy_localstack_deployment
        echo ""
    fi
    
    # Test AWS
    measure_aws_deployment $i "$SHOULD_DESTROY"
    echo ""
    
    # Destroy AWS after measurement (unless it's the last iteration)
    if [ "$DESTROY_BETWEEN" == "true" ] && [ $i -lt $NUM_ITERATIONS ]; then
        destroy_aws_deployment > /dev/null 2>&1
        echo ""
    fi
done

# Final cleanup: Destroy all resources after last iteration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Final Cleanup: Destroying all resources"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Destroying LocalStack deployment..."
cd "${PROJECT_ROOT}/infra/CS6650_2b_demo/terraform"
terraform workspace select localstack 2>/dev/null
if terraform state list 2>/dev/null | grep -q .; then
    destroy_localstack_deployment > /dev/null 2>&1
    echo "  ✅ LocalStack resources destroyed"
else
    echo "  ℹ️  No LocalStack resources to destroy"
fi
echo ""

echo "Destroying AWS deployment..."
terraform workspace select default 2>/dev/null
if terraform state list 2>/dev/null | grep -q .; then
    destroy_aws_deployment > /dev/null 2>&1
    echo "  ✅ AWS resources destroyed"
else
    echo "  ℹ️  No AWS resources to destroy"
fi
echo ""

echo "✅ All resources cleaned up. Original state restored."
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "Results saved to: ${OUTPUT_FILE}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
cat "${OUTPUT_FILE}"

