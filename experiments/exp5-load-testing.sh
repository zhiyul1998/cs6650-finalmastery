#!/bin/bash

# Experiment 5: Load Testing & Scalability
# Uses Locust to test both environments under various load conditions

set -e

RESULTS_DIR="$1"
AWS_ENDPOINT="$2"
LOCALSTACK_ENDPOINT="$3"

if [ -z "$RESULTS_DIR" ] || [ -z "$AWS_ENDPOINT" ] || [ -z "$LOCALSTACK_ENDPOINT" ]; then
    echo "Usage: $0 <results_directory> <aws_endpoint> <localstack_endpoint>"
    exit 1
fi

echo "═══════════════════════════════════════════════════════════════"
echo "Experiment 5: Load Testing & Scalability"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "AWS Endpoint: $AWS_ENDPOINT"
echo "LocalStack Endpoint: $LOCALSTACK_ENDPOINT"
echo ""

# Check if Locust is installed
if ! command -v locust &> /dev/null; then
    echo "❌ Error: Locust is not installed"
    echo "Install with: pip install locust"
    exit 1
fi

# Load test scenarios
SCENARIOS=(
    "10:1"   # 10 users, 1 req/sec each
    "50:2"   # 50 users, 2 req/sec each
    "100:5"  # 100 users, 5 req/sec each
)

# Function to run Locust test
run_locust_test() {
    local env=$1
    local endpoint=$2
    local users=$3
    local spawn_rate=$4
    local duration=${5:-60}
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Testing $env with $users users, $spawn_rate spawn rate, ${duration}s duration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local output_dir="${RESULTS_DIR}/locust_${env}_${users}users"
    mkdir -p "$output_dir"
    
    # Run Locust in headless mode
    locust -f locustfile.py \
        --headless \
        --host="$endpoint" \
        --users="$users" \
        --spawn-rate="$spawn_rate" \
        --run-time="${duration}s" \
        --html="${output_dir}/report.html" \
        --csv="${output_dir}/results" \
        --loglevel=WARNING
    
    echo "  ✅ Test complete. Results in: $output_dir"
    echo ""
}

# Test AWS
for scenario in "${SCENARIOS[@]}"; do
    IFS=':' read -r users spawn_rate <<< "$scenario"
    run_locust_test "AWS" "$AWS_ENDPOINT" "$users" "$spawn_rate" 60
    sleep 10  # Cool down period
done

# Test LocalStack
for scenario in "${SCENARIOS[@]}"; do
    IFS=':' read -r users spawn_rate <<< "$scenario"
    run_locust_test "LocalStack" "$LOCALSTACK_ENDPOINT" "$users" "$spawn_rate" 60
    sleep 10  # Cool down period
done

echo "═══════════════════════════════════════════════════════════════"
echo "All load tests complete!"
echo "Results saved in: ${RESULTS_DIR}/locust_*"
echo "═══════════════════════════════════════════════════════════════"

