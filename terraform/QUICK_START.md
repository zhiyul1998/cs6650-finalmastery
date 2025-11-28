# Quick Start Guide

This guide provides step-by-step instructions for deploying the e-commerce backend infrastructure to both **AWS Learner Lab** and **LocalStack Pro**.

## Prerequisites

Before deploying, ensure you have:

- ✅ **Terraform** installed (v1.0+)
- ✅ **Docker** installed and running
- ✅ **AWS CLI** installed and configured
- ✅ **LocalStack Pro** access (for LocalStack deployment)

---

## AWS Learner Lab Deployment

### Step 1: Configure AWS Credentials

If you haven't already configured AWS credentials for your Learner Lab:

```bash
aws configure
```

Set your session token:
```bash
aws configure set aws_session_token <YOUR-TEMP-SESSION-TOKEN>
```

### Step 2: Deploy Infrastructure

Navigate to the terraform directory and run the deployment script:

```bash
cd infra/CS6650_2b_demo/terraform
./deploy-aws.sh
```

**What this does:**
- Initializes Terraform
- Creates ECR repository
- Builds and pushes Docker image to ECR
- Creates ECS cluster, task definition, and service
- Sets up VPC, security groups, and CloudWatch logs
- Deploys your FastAPI application

### Step 3: Get Public IP Address

After deployment completes, get the public IP of your ECS service:

```bash
PUBLIC_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $(aws ecs describe-tasks \
    --cluster $(terraform output -raw ecs_cluster_name) \
    --tasks $(aws ecs list-tasks \
      --cluster $(terraform output -raw ecs_cluster_name) \
      --service-name $(terraform output -raw ecs_service_name) \
      --query 'taskArns[0]' --output text) \
    --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
    --output text) \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text)

echo "API Endpoint: http://$PUBLIC_IP:8080"
```

### Step 4: Test the API

```bash
# GET request - Get product by ID
curl http://$PUBLIC_IP:8080/v1/products/1

# POST request - Update product details
curl -i -X POST http://$PUBLIC_IP:8080/v1/products/1/details \
  -H "Content-Type: application/json" \
  -d '{"id":1,"name":"Updated T-Shirt","price":13.99,"description":"New color"}'
```

### Step 5: Clean Up (When Done)

```bash
terraform destroy -var="deployment_target=aws" -auto-approve
```

---

## LocalStack Pro Deployment

### Step 1: Start LocalStack Pro

Start LocalStack Pro with your authentication token:

```bash
cd infra/CS6650_2b_demo/terraform
./start-localstack-pro.sh
```

**What this does:**
- Stops any existing LocalStack containers
- Starts LocalStack Pro Docker container
- Configures required services (EC2, ECS, ECR, IAM, CloudWatch Logs)
- Waits for services to be ready
- Verifies ECS/ECR are available

**Note:** The script uses the auth token: `ls-vUTegobo-yuda-cUDi-2732-QeloFagO10b9`

If you need to use a different token, set it:
```bash
export LOCALSTACK_AUTH_TOKEN=your-token-here
./start-localstack-pro.sh
```

### Step 2: Deploy Infrastructure

Deploy to LocalStack:

```bash
./deploy-localstack-now.sh
```

**What this does:**
- Checks if LocalStack is running (starts it if not)
- Creates/selects Terraform workspace for LocalStack (separate from AWS)
- Initializes Terraform
- Creates ECR repository in LocalStack
- Builds and pushes Docker image to LocalStack ECR
- Creates ECS cluster, task definition, and service in LocalStack
- Sets up networking and logging
- Deploys your FastAPI application

### Step 3: Get Service Endpoint

LocalStack assigns a **random port** each time you deploy. Get the current endpoint:

```bash
./get-localstack-endpoint.sh
```

This will output:
```
API Endpoint: http://localhost:61471
```

**Important:** The port number changes every time you redeploy. Always run `./get-localstack-endpoint.sh` after deployment to get the current port.

### Step 4: Test the API

Use the endpoint from Step 3:

```bash
# Get the endpoint first
./get-localstack-endpoint.sh

# Then test (replace 61471 with your actual port)
curl http://localhost:61471/v1/products/1

# POST request
curl -i -X POST http://localhost:61471/v1/products/1/details \
  -H "Content-Type: application/json" \
  -d '{"id":1,"name":"Updated T-Shirt","price":13.99,"description":"New color"}'
```

### Step 5: Clean Up (When Done)

```bash
# Destroy infrastructure
terraform destroy -var="deployment_target=localstack" -auto-approve

# Stop LocalStack container (optional)
docker stop localstack-pro
```

---

## Key Differences: AWS vs LocalStack

| Aspect | AWS Learner Lab | LocalStack Pro |
|--------|----------------|----------------|
| **Endpoint** | Public IP (e.g., `http://54.123.45.67:8080`) | Localhost with random port (e.g., `http://localhost:61471`) |
| **Port** | Fixed (8080) | Dynamic (changes each deployment) |
| **Cost** | Uses Learner Lab credits | Free (local) |
| **Access** | Internet accessible | Localhost only |
| **State** | Default workspace | Separate workspace (`localstack`) |
| **Speed** | Slower (cloud) | Faster (local) |

---

## Troubleshooting

### LocalStack: Port not accessible

If you can't connect to the API:
1. Verify LocalStack is running: `docker ps | grep localstack-pro`
2. Get the current endpoint: `./get-localstack-endpoint.sh`
3. Check container logs: `docker logs localstack-pro`

### LocalStack: ECS/ECR not available

If you see errors about ECS/ECR not being available:
1. Verify Pro license: Check that `start-localstack-pro.sh` includes your auth token
2. Check service health: `curl http://localhost:4566/_localstack/health | grep -i ecs`
3. Restart LocalStack: `./start-localstack-pro.sh`

### AWS: Deployment fails

1. Verify credentials: `aws sts get-caller-identity`
2. Check session token hasn't expired
3. Verify you're using the correct AWS region (us-west-2)

### General: Terraform state issues

If you encounter state conflicts between AWS and LocalStack:
- Use Terraform workspaces (handled automatically by `deploy-localstack-now.sh`)
- For AWS: Default workspace
- For LocalStack: `localstack` workspace

---

## Manual Deployment (Alternative)

If you prefer to run Terraform commands manually:

### AWS:
```bash
terraform workspace select default  # or create new workspace
terraform init
terraform apply -var="deployment_target=aws"
```

### LocalStack:
```bash
terraform workspace select localstack || terraform workspace new localstack
terraform init
terraform apply -var="deployment_target=localstack" \
                -var="localstack_endpoint=http://localhost:4566"
```

---

## Next Steps

After successfully deploying to both environments, you can:

1. **Performance Testing**: Compare response times between AWS and LocalStack
2. **Load Testing**: Use Locust to test both endpoints
3. **Cost Analysis**: Compare costs (AWS charges vs free LocalStack)
4. **Development Workflow**: Use LocalStack for fast iteration, AWS for realistic testing

---

## Available Scripts

| Script | Purpose |
|--------|---------|
| `deploy-aws.sh` | Deploy to AWS Learner Lab |
| `deploy-localstack-now.sh` | Deploy to LocalStack Pro |
| `start-localstack-pro.sh` | Start LocalStack Pro container |
| `get-localstack-endpoint.sh` | Get current LocalStack API endpoint |

## Configuration

You can customize deployment by copying and editing:
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your preferences
```

Then deploy:
```bash
terraform apply -var-file=terraform.tfvars
```

