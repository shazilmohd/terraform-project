# Terraform Modules & Environment Repository

A production-ready Terraform repository with reusable modules and environment-specific configurations for AWS infrastructure deployment.

## Repository Structure

```
.
├── modules/                          # Reusable Terraform modules
│   ├── compute/
│   │   └── ec2/                     # EC2 instance module
│   ├── networking/
│   │   ├── vpc/                     # VPC with subnets module
│   │   └── security_group/          # Security group module
│   └── secrets/
│       └── secret_manager/          # AWS Secrets Manager module
├── env/                             # Environment-specific configurations
│   ├── dev/                         # Development environment
│   └── stage/                       # Staging environment
├── scripts/                         # Utility scripts
│   └── install_apache2.sh          # Apache2 installation script
└── README.md                        # This file
```

---

## Modules Overview

### 1. Networking: VPC Module
**Location:** `modules/networking/vpc/`

Creates a complete VPC infrastructure with public and private subnets.

**Key Features:**
- Configurable CIDR block
- Auto-distributed availability zones
- Internet Gateway integration
- Public route tables

**Usage:**
```hcl
module "vpc" {
  source = "../../modules/networking/vpc"
  
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.2.0/24"]
  tags = { Environment = "dev" }
}
```

---

### 2. Networking: Security Group Module
**Location:** `modules/networking/security_group/`

Manages security group ingress and egress rules.

**Key Features:**
- Flexible ingress/egress rules
- Default allow-all egress
- Parameterized protocol and port configuration

**Usage:**
```hcl
module "web_security_group" {
  source = "../../modules/networking/security_group"
  
  vpc_id              = module.vpc.vpc_id
  security_group_name = "web-sg"
  
  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP access"
    }
  ]
}
```

---

### 3. Compute: EC2 Module
**Location:** `modules/compute/ec2/`

Launches EC2 instances with flexible configuration.

**Key Features:**
- Multiple instance support via `count`
- Configurable AMI, instance type, storage
- User data script execution
- Public IP assignment control

**Usage:**
```hcl
module "web_server" {
  source = "../../modules/compute/ec2"
  
  instance_type      = "t2.micro"
  ami_id             = "ami-0c55b159cbfafe1f0"
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [module.web_security_group.security_group_id]
  user_data          = file("scripts/install_apache2.sh")
  instance_count     = 1
}
```

---

### 4. Secrets: Secrets Manager Module
**Location:** `modules/secrets/secret_manager/`

Manages secrets in AWS Secrets Manager.

**Key Features:**
- Create secrets with optional values
- Configure recovery windows
- Version management

**Usage:**
```hcl
module "app_secrets" {
  source = "../../modules/secrets/secret_manager"
  
  secret_name = "app-secrets"
  description = "Application secrets"
}
```

---

## Environment Configurations

### Development Environment
**Location:** `env/dev/`

**Configuration:**
- Small, single t2.micro instance
- Minimal subnet configuration
- Lower storage (20GB)
- For testing and development

**Files:**
- `main.tf` - Module integration and data sources
- `variables.tf` - Variable definitions
- `outputs.tf` - Output values
- `terraform.tfvars` - Dev-specific values

### Staging Environment
**Location:** `env/stage/`

**Configuration:**
- Multiple t2.small instances (2)
- Multiple subnets across AZs
- Higher storage (30GB)
- For pre-production testing

**Files:**
- `main.tf` - Module integration and data sources
- `variables.tf` - Variable definitions
- `outputs.tf` - Output values
- `terraform.tfvars` - Stage-specific values

---

## Key Features

### ✅ No Hardcoding
- All values parameterized in modules
- Environment-specific values in `terraform.tfvars`
- Dynamic AMI lookup using data sources

### ✅ AWS Secrets Manager Integration
- Environment variables stored in Secrets Manager
- Retrieved via `data "aws_secretsmanager_secret_version"`
- Sensitive variables marked as `sensitive = true`

### ✅ Apache2 Automation
- Automated installation via user_data script
- Health check page served on port 80
- Script located at `scripts/install_apache2.sh`

### ✅ Security Best Practices
- Separate security group module
- Automatic latest Ubuntu LTS AMI selection
- Optional key pair integration
- Egress rules properly configured

### ✅ Environment Isolation
- Separate tfvars for each environment
- Distinct CIDR ranges (10.0.x.x for dev, 10.1.x.x for stage)
- Environment tags on all resources

---

## Getting Started

### Prerequisites
- Terraform >= 1.0
- AWS CLI configured with credentials
- AWS Secrets Manager secret created with required values

### 1. Create Secrets in AWS Secrets Manager

```bash
# For development
aws secretsmanager create-secret \
  --name dev/terraform-env-vars \
  --secret-string '{"key1":"value1","key2":"value2"}'

# For staging
aws secretsmanager create-secret \
  --name stage/terraform-env-vars \
  --secret-string '{"key1":"value1","key2":"value2"}'
```

### 2. Configure Environment Variables

Edit `env/dev/terraform.tfvars` or `env/stage/terraform.tfvars` with your values:

```hcl
aws_region = "us-east-1"
vpc_cidr = "10.0.0.0/16"
instance_type = "t2.micro"
secrets_manager_secret_name = "dev/terraform-env-vars"
```

### 3. Deploy Infrastructure

```bash
cd env/dev

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

### 4. Access Your Web Server

```bash
# Get the public IP from outputs
terraform output web_server_public_ips

# Visit in browser (e.g., http://10.0.1.x)
curl http://<public-ip>
```

---

## SSH Access to EC2

```bash
ssh -i /path/to/key.pem ubuntu@<public-ip>
```

---

## Cleanup

```bash
# Destroy resources in reverse order
terraform destroy
```

---

## Best Practices Implemented

1. **Module Design**
   - Single responsibility principle
   - All inputs parameterized
   - Clear outputs for inter-module communication

2. **Variable Management**
   - Sensitive variables marked
   - Default values where appropriate
   - Type constraints specified

3. **Data Sources**
   - Dynamic AMI lookup (no hardcoded AMI IDs)
   - Secrets Manager integration for sensitive data
   - Availability zone discovery

4. **Tagging Strategy**
   - Consistent environment tagging
   - Resource name patterns
   - Merge function for flexible tag management

5. **Git Safety**
   - `.gitignore` excludes state files and tfvars
   - Secrets stored in AWS Secrets Manager
   - No hardcoded credentials

---

## Troubleshooting

### Terraform Apply Fails
1. Verify AWS credentials: `aws sts get-caller-identity`
2. Check Secrets Manager secret exists: `aws secretsmanager get-secret-value --secret-id dev/terraform-env-vars`
3. Verify AMI availability in your region

### EC2 Instance Not Responding
1. Check security group ingress rules
2. Verify public IP assignment
3. Check EC2 instance status in AWS Console

### Apache2 Not Running
1. SSH to instance and check: `sudo systemctl status apache2`
2. Check user_data logs: `cat /var/log/cloud-init-output.log`
3. Verify security group allows port 80

---

## Contributing

When adding new modules:
1. Follow the naming convention: `modules/category/resource-type/`
2. Include `variables.tf`, `main.tf`, `outputs.tf`
3. Add usage examples to README
4. Ensure no hardcoded values

---

## License

This repository is for educational and organizational use.
