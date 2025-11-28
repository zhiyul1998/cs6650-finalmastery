#!/bin/bash

# Configuration file for experiments
# Update these values with your deployment endpoints

# AWS Endpoint (get from deployment)
# Format: http://<PUBLIC_IP>:8080
export AWS_ENDPOINT="http://YOUR_AWS_IP:8080"

# LocalStack Endpoint (get from: ./get-localstack-endpoint.sh)
# Format: http://localhost:<PORT>
export LOCALSTACK_ENDPOINT="http://localhost:61471"

# Experiment settings
export NUM_ITERATIONS=3  # Number of runs for statistical validity
export LOAD_TEST_DURATION=60  # Duration in seconds for load tests
export LOAD_TEST_USERS=50  # Number of concurrent users

# AWS Configuration
export AWS_REGION="us-west-2"
export AWS_CLUSTER_NAME="CS6650L2-cluster"
export AWS_SERVICE_NAME="CS6650L2"

# LocalStack Configuration  
export LOCALSTACK_CLUSTER_NAME="CS6650L2-cluster"
export LOCALSTACK_SERVICE_NAME="CS6650L2"

# Output settings
export RESULTS_DIR="experiment-results"
export VERBOSE=false  # Set to true for detailed logging

