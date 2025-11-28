# E-commerce Product API

A small e-commerce product API built with **FastAPI**, containerized with **Docker**, and deployed to **AWS ECS (Fargate)** using **Terraform**.

## Project Structure

Homework 5/

├─ ecommerce-api/ # Application code

├─ app/ # FastAPI server

    ├─ main.py

    └─ models.py

├─ requirements.txt # Python dependencies

└─ Dockerfile # Container definition

└─ terraform/ # Infrastructure as Code (IaC)

    ├─ main.tf             # ECS/ECR wiring

    ├─ variables.tf        # Configurable variables

    ├─ outputs.tf

    ├─ provider.tf

    └─ modules/

### Deploy Instructions

Anyone can spin up this stack in their own AWS account (region: **us-west-2**).

Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) installed
- [Docker](https://docs.docker.com/get-docker/) installed
- AWS CLI configured (`aws configure`) with valid IAM credentials
- An existing IAM role named **LabRole** (from Learner Lab)

Steps

- **Clone the repo**

```bash
git clone https://github.khoury.northeastern.edu/hazel98/cs6650hw5.git
cd Homework\ 5/terraform
```

- **Initialize Terraform**

  ```
  terraform init
  terraform apply -auto-approve
  ```

- **Get public ip address**

  ```
  aws ec2 describe-network-interfaces \
  --network-interface-ids $(
      aws ecs describe-tasks \
      --cluster $(terraform output -raw ecs_cluster_name) \
      --tasks $(
          aws ecs list-tasks \
          --cluster $(terraform output -raw ecs_cluster_name) \
          --service-name $(terraform output -raw ecs_service_name) \
          --query 'taskArns[0]' --output text
      ) \
      --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
      --output text
  ) \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text
  ```

- **Test API**

  ```
  Get: curl -i http://<PUBLIC_IP>:8080/v1/products/1
  Post: curl -i -X POST http://<PUBLIC_IP>:8080/v1/products/1/details \
    -H "Content-Type: application/json" \
    -d '{"id":1,"name":"Updated T-Shirt","price":13.99,"description":"New color"}'
  ```

- **Cleanup**

  ```
  terraform destroy -auto-approve
  ```

#### API Endpoints

1. **GET v1/products/**

Retrieve a product by ID.

- ✅ **200 OK** : Product found
- ❌ **404 Not Found** : Invalid ID
- ❌ **500 Internal Server Error** : Unexpected issue

2. **POST v1/products//details**

Update product details.

- ✅ **204 No Content** : Successfully updated
- ❌ **400 Bad Request** : Body `id` mismatch with path
- ❌ **404 Not Found** : Product doesn’t exist
- ❌ **500 Internal Server Error** : Unexpected issue
