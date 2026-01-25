# Compute Node Service

A microservice for provisioning and managing compute nodes in the Pennsieve platform, providing serverless infrastructure for data processing workflows.

## Overview

The Compute Node Service is responsible for:
- Creating and managing compute infrastructure for data processing
- Provisioning AWS Fargate containers for compute workloads
- Managing compute node lifecycle (create, read, delete operations)
- Integrating with the Pennsieve workflow management system

## Architecture

The service consists of two main components:

### 1. Lambda Function (API Layer)
- **Location**: `lambda/service/`
- **Language**: Go
- **Purpose**: Provides REST API endpoints for compute node management
- **Endpoints**:
  - `POST /compute-nodes` - Create a new compute node
  - `GET /compute-nodes` - List all compute nodes
  - `GET /compute-nodes/{id}` - Get specific compute node details
  - `DELETE /compute-nodes/{id}` - Delete a compute node

### 2. Fargate Provisioner
- **Location**: `fargate/compute-node-provisioner/`
- **Language**: Go
- **Purpose**: Handles the actual infrastructure provisioning using Terraform
- **Features**:
  - Terraform-based infrastructure as code
  - Support for both CPU and GPU compute resources
  - EFS volume mounting for data persistence
  - S3 integration for artifact storage

## Prerequisites

- Go 1.x or higher
- Docker and Docker Compose
- AWS CLI configured with appropriate credentials
- Terraform (for infrastructure deployment)
- Make utility

## Development Setup

1. Clone the repository:
```bash
git clone https://github.com/Pennsieve/compute-node-service.git
cd compute-node-service
```

2. Set up environment variables:
```bash
cp fargate/compute-node-provisioner/env.dev.sample .env
# Edit .env with your configuration
```

3. Install dependencies:
```bash
cd lambda/service && go mod download
cd ../../fargate/compute-node-provisioner && go mod download
```

## Building

### Build Lambda Function
```bash
make package
```

This command:
- Builds the Lambda function for ARM64 architecture
- Creates a deployment package as a ZIP file
- Builds and pushes the Fargate provisioner Docker image

### Build for Local Testing
```bash
docker-compose -f docker-compose.test.yml build
```

## Testing

Run the test suite locally:
```bash
make test
```

For CI environment testing:
```bash
make test-ci
```

## Deployment

### Deploy Lambda Function
```bash
make publish
```

This will:
1. Build the Lambda deployment package
2. Upload to S3 bucket (`pennsieve-cc-lambda-functions-use1`)
3. Build and push the Fargate provisioner container

### Infrastructure Deployment

The service uses Terraform for infrastructure management:

```bash
cd terraform
terraform init
terraform plan -var="environment_name=dev" -var="image_tag=latest"
terraform apply -var="environment_name=dev" -var="image_tag=latest"
```

## Configuration

### Environment Variables

#### Lambda Service
- `COMPUTE_NODES_TABLE` - DynamoDB table name for storing compute node data
- `AWS_REGION` - AWS region for deployment

#### Fargate Provisioner
- `COMPUTE_NODE_ID` - Unique identifier for the compute node
- `ACTION` - Action to perform (CREATE/DELETE)
- `ACCOUNT_UUID` - Account unique identifier
- `ACCOUNT_ID` - AWS account ID
- `ACCOUNT_TYPE` - Type of account (e.g., workspace)
- `ORG_ID` - Organization identifier
- `USER_ID` - User identifier
- `ENV` - Environment (dev/staging/prod)
- `NODE_NAME` - Name of the compute node
- `NODE_DESCRIPTION` - Description of the compute node
- `WM_TAG` - Workflow manager Docker image tag
- `NODE_IDENTIFIER` - Unique node identifier (auto-generated)

## Infrastructure Components

### AWS Resources Created
- **ECS Fargate Tasks** - For running compute workloads
- **EFS File System** - For persistent storage
- **S3 Buckets** - For artifact and data storage
- **DynamoDB Table** - For compute node metadata
- **CloudWatch Logs** - For monitoring and debugging
- **IAM Roles** - For service permissions
- **Lambda Function** - For API endpoints

### GPU Support
The service includes GPU support through specialized ECS task definitions and capacity providers. GPU resources can be provisioned by specifying appropriate task requirements.

## Monitoring

### CloudWatch Metrics
The service publishes custom metrics to CloudWatch:
- Compute node creation/deletion events
- Task execution status
- Resource utilization

### Logging
All components log to CloudWatch Logs:
- Lambda logs: `/aws/lambda/compute-node-service-{env}`
- Fargate logs: `/ecs/compute-node-provisioner-{env}`

## CI/CD

The service uses Jenkins for continuous integration and deployment:

1. **Test Stage**: Runs automated tests
2. **Build & Push Stage**: Builds artifacts and Docker images
3. **Deploy Stage**: Deploys to target environment (dev/staging/prod)

The pipeline is triggered on pushes to the `main` branch.

## Project Structure

```
compute-node-service/
├── lambda/
│   └── service/         # Lambda function code
│       ├── handler/     # HTTP request handlers
│       ├── models/      # Data models
│       ├── runner/      # Task execution logic
│       ├── store_dynamodb/ # DynamoDB integration
│       └── utils/       # Utility functions
├── fargate/
│   └── compute-node-provisioner/  # Fargate provisioner
│       ├── provisioner/ # Provisioning logic
│       ├── scripts/     # Helper scripts
│       └── terraform/   # Infrastructure as code
├── terraform/          # Service infrastructure
├── Makefile           # Build automation
├── Jenkinsfile        # CI/CD pipeline
└── docker-compose.test.yml  # Test environment

```

## API Reference

### Create Compute Node
```http
POST /compute-nodes
Content-Type: application/json

{
  "name": "my-compute-node",
  "description": "Processing node for data analysis",
  "account_uuid": "uuid",
  "organization_id": "org-123",
  "user_id": "user-456"
}
```

### Get Compute Nodes
```http
GET /compute-nodes
```

### Get Specific Compute Node
```http
GET /compute-nodes/{id}
```

### Delete Compute Node
```http
DELETE /compute-nodes/{id}
```

## Development Commands

```bash
# Run tests
make test

# Clean up test environment
make clean

# Build Lambda package
make package

# Publish Lambda to S3
make publish

# Tidy Go modules
make tidy

# View help
make help
```

## Troubleshooting

### Common Issues

1. **Lambda build fails**: Ensure Go is installed and GOARCH is set correctly
2. **Docker build errors**: Check Docker daemon is running and credentials are configured
3. **Terraform errors**: Verify AWS credentials and permissions
4. **DynamoDB errors**: Check table exists and has proper indexes

### Debug Mode

Enable debug logging by setting:
```bash
export DEBUG=true
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
- Create an issue in the GitHub repository
- Contact the Pennsieve platform team

## Related Services

- [Pennsieve Platform](https://github.com/Pennsieve/pennsieve-api)
- [Workflow Manager](https://github.com/Pennsieve/workflow-manager)
- [Data Processing Pipeline](https://github.com/Pennsieve/data-pipeline)