#!/bin/bash

# Experiment 2: API Performance & Latency
# Measures response times, throughput, and latency characteristics

set -e

RESULTS_DIR="$1"
AWS_ENDPOINT="$2"
LOCALSTACK_ENDPOINT="$3"

if [ -z "$RESULTS_DIR" ] || [ -z "$AWS_ENDPOINT" ] || [ -z "$LOCALSTACK_ENDPOINT" ]; then
    echo "Usage: $0 <results_directory> <aws_endpoint> <localstack_endpoint>"
    echo "Example: $0 ./results http://54.123.45.67:8080 http://localhost:61471"
    exit 1
fi

OUTPUT_FILE="${RESULTS_DIR}/exp2-performance.csv"
LATENCY_FILE="${RESULTS_DIR}/exp2-latency-details.json"

echo "═══════════════════════════════════════════════════════════════"
echo "Experiment 2: API Performance & Latency"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "AWS Endpoint: $AWS_ENDPOINT"
echo "LocalStack Endpoint: $LOCALSTACK_ENDPOINT"
echo ""

# Create CSV header
echo "Environment,Operation,Min(ms),Max(ms),Avg(ms),P50(ms),P95(ms),P99(ms),TotalRequests,Errors" > "${OUTPUT_FILE}"

# Function to test endpoint performance
test_endpoint_performance() {
    local env=$1
    local endpoint=$2
    local operation=$3  # "get" or "post"
    local num_requests=${4:-100}
    
    echo "Testing $env - $operation ($num_requests requests)..."
    
    local temp_file="/tmp/perf_${env}_${operation}.txt"
    
    # Run requests and capture timing
    local success_count=0
    local error_count=0
    local times=()
    
    for i in $(seq 1 $num_requests); do
        if [ "$operation" == "get" ]; then
            # GET request
            product_id=$((RANDOM % 10 + 1))
            start=$(date +%s.%N)
            http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${endpoint}/v1/products/${product_id}")
            end=$(date +%s.%N)
            
            duration=$(echo "($end - $start) * 1000" | bc)
            times+=($duration)
            
            if [ "$http_code" == "200" ]; then
                ((success_count++))
            else
                ((error_count++))
            fi
        else
            # POST request
            product_id=$((RANDOM % 10 + 1))
            start=$(date +%s.%N)
            http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
                -X POST "${endpoint}/v1/products/${product_id}/details" \
                -H "Content-Type: application/json" \
                -d "{\"id\":${product_id},\"name\":\"Test\",\"price\":10.99}")
            end=$(date +%s.%N)
            
            duration=$(echo "($end - $start) * 1000" | bc)
            times+=($duration)
            
            if [ "$http_code" == "204" ]; then
                ((success_count++))
            else
                ((error_count++))
            fi
        fi
        
        # Progress indicator
        if [ $((i % 10)) -eq 0 ]; then
            echo -n "."
        fi
    done
    
    echo "" # New line after progress dots
    
    # Calculate statistics
    # Sort times and calculate percentiles
    if [ ${#times[@]} -eq 0 ]; then
        echo "  ⚠️  Warning: No successful requests recorded"
        echo "$env,$operation,0,0,0,0,0,0,0,$error_count" >> "${OUTPUT_FILE}"
        return
    fi
    
    # Sort the array
    IFS=$'\n' sorted=($(printf '%s\n' "${times[@]}" | sort -n))
    unset IFS
    
    local count=${#sorted[@]}
    if [ $count -eq 0 ]; then
        echo "  ⚠️  Warning: No times recorded after sorting"
        echo "$env,$operation,0,0,0,0,0,0,0,$error_count" >> "${OUTPUT_FILE}"
        return
    fi
    
    local min=${sorted[0]}
    local max_idx=$((count - 1))
    local max=${sorted[$max_idx]}
    
    # Calculate average
    local sum=0
    for t in "${sorted[@]}"; do
        sum=$(echo "scale=2; $sum + $t" | bc 2>/dev/null || echo "$sum")
    done
    local avg=$(echo "scale=2; $sum / $count" | bc 2>/dev/null || echo "0")
    
    # Calculate percentiles (ensure indices are valid)
    local p50_idx=$((count * 50 / 100))
    local p95_idx=$((count * 95 / 100))
    local p99_idx=$((count * 99 / 100))
    
    # Ensure indices don't exceed array bounds
    [ $p50_idx -ge $count ] && p50_idx=$((count - 1))
    [ $p95_idx -ge $count ] && p95_idx=$((count - 1))
    [ $p99_idx -ge $count ] && p99_idx=$((count - 1))
    
    local p50=${sorted[$p50_idx]}
    local p95=${sorted[$p95_idx]}
    local p99=${sorted[$p99_idx]}
    
    # Write to CSV
    echo "$env,$operation,$min,$max,$avg,$p50,$p95,$p99,$success_count,$error_count" >> "${OUTPUT_FILE}"
    
    echo "  ✅ Completed: Min=${min}ms, Avg=${avg}ms, P95=${p95}ms, Errors=${error_count}"
}

# Test both endpoints
echo "Running performance tests..."
echo ""

# AWS Tests
test_endpoint_performance "AWS" "$AWS_ENDPOINT" "get" 100
test_endpoint_performance "AWS" "$AWS_ENDPOINT" "post" 100

echo ""

# LocalStack Tests
test_endpoint_performance "LocalStack" "$LOCALSTACK_ENDPOINT" "get" 100
test_endpoint_performance "LocalStack" "$LOCALSTACK_ENDPOINT" "post" 100

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Results saved to: ${OUTPUT_FILE}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
cat "${OUTPUT_FILE}"

