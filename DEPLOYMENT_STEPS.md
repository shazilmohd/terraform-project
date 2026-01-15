# Complete Terraform Infrastructure Deployment Guide - DEV Environment

## Project Analysis

### Directory Structure
```
Terraform-project/
├── Jenkinsfile                    # CI/CD Pipeline
├── jenkins.env                    # Jenkins configuration
├── env/
│   ├── dev/                      # Development environment
│   │   ├── main.tf               # VPC, EC2, Security Group, Secrets modules
│   │   ├── variables.tf          # Input variables
│   │   ├── outputs.tf            # Output values
│   │   └── terraform.tfvars      # Dev-specific values (git-ignored)
│   └── stage/                    # Staging environment
├── modules/
│   ├── compute/ec2/              # EC2 instance module
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   └── outputs.tf
│   ├── networking/
│   │   ├── vpc/                  # VPC module
│   │   │   ├── variables.tf
│   │   │   ├── main.tf
│   │   │   └── outputs.tf
│   │   └── security_group/       # Security Group module
│   │       ├── variables.tf
│   │       ├── main.tf
│   │       └── outputs.tf
│   └── secrets/
│       └── secret_manager/       # Secrets Manager module
│           ├── variables.tf
│           ├── main.tf
│           └── outputs.tf
└── scripts/
    ├── install_apache2.sh        # EC2 user-data script
    ├── validate_deployment.sh    # Pre-deployment validation
    └── load_jenkins_config.sh    # Load Jenkins config
```

### What Gets Deployed in DEV
```
AWS Dev Environment
├── VPC
│   ├── CIDR: 10.0.0.0/16
│   ├── Public Subnet: 10.0.1.0/24 (with IGW)
│   └── Private Subnet: 10.0.2.0/24
├── Internet Gateway
├── Route Tables (public)
├── Security Group
│   ├── Inbound HTTP (80)
│   ├── Inbound HTTPS (443)
│   └── Inbound SSH (22)
├── EC2 Instance (1x t2.micro)
│   ├── AMI: Ubuntu 22.04 LTS (latest)
│   ├── User Data: Apache2 installation
│   └── Public IP: Assigned
└── Secrets Manager
    └── dev/terraform-env-vars
```

---

# Step-by-Step Deployment Steps

## PHASE 1: PRE-DEPLOYMENT SETUP (One-time)

### Step 1: Prerequisites Installation

#### On Your Local Machine:

```bash
# 1. Install Terraform
brew install terraform  # macOS
# OR
sudo apt-get install terraform  # Ubuntu/Linux

# 2. Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 3. Install Git
brew install git  # macOS
sudo apt-get install git  # Linux

# 4. Verify installations
terraform version
aws --version
git --version
```

#### Jenkins Server:
```bash
# SSH to Jenkins server
ssh jenkins-user@jenkins-server

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
unzip terraform_1.5.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify
terraform version
aws --version
```

### Step 2: AWS Setup

#### Create AWS Account & User

```bash
# 1. Create IAM User for Terraform
# AWS Console → IAM → Users → Create user
# User name: terraform-user
# Enable "Programmatic access"

# 2. Attach Policies
# Attach policy: "PowerUserAccess" (or create custom policy)
# Actions needed:
#   - ec2:*
#   - vpc:*
#   - security-groups:*
#   - secretsmanager:*
#   - iam:PassRole (if using roles)

# 3. Generate Access Keys
# AWS Console → IAM → Users → terraform-user → Security credentials
# → Create access key
# Save: Access Key ID & Secret Access Key
```

#### Configure AWS CLI Locally

```bash
# Configure AWS credentials
aws configure

# When prompted:
AWS Access Key ID: <your-access-key>
AWS Secret Access Key: <your-secret-key>
Default region: us-east-1
Default output format: json

# Verify configuration
aws sts get-caller-identity

# Output:
# {
#     "UserId": "AIDAI...",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/terraform-user"
# }
```

### Step 3: Create AWS Secrets Manager Secret

```bash
# Create secret for dev environment
aws secretsmanager create-secret \
  --name dev/terraform-env-vars \
  --region us-east-1 \
  --secret-string '{
    "db_password": "your-db-password",
    "api_key": "your-api-key",
    "other_var": "value"
  }'

# Verify secret was created
aws secretsmanager describe-secret --secret-id dev/terraform-env-vars
```

### Step 4: Create EC2 Key Pair

```bash
# Create key pair
aws ec2 create-key-pair \
  --key-name my-dev-keypair \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/my-dev-keypair.pem

# Set permissions
chmod 400 ~/.ssh/my-dev-keypair.pem

# Verify
aws ec2 describe-key-pairs --region us-east-1
```

### Step 5: Clone Repository

```bash
# Clone the terraform project
git clone https://github.com/your-org/terraform-project.git
cd terraform-project

# Verify structure
tree -L 2

# Output should show all modules and environments
```

### Step 6: Update Configuration Files

#### Update jenkins.env

```bash
# Edit jenkins.env
vim jenkins.env

# Set your values:
GIT_REPO_URL=https://github.com/your-org/terraform-project.git
GIT_BRANCH=*/main
JENKINS_APPROVERS=terraform-approvers
JENKINS_NOTIFY_EMAIL=devops-team@example.com
AWS_REGION=us-east-1
TERRAFORM_VERSION=1.5.0
```

#### Update env/dev/terraform.tfvars

```bash
# Edit terraform.tfvars
vim env/dev/terraform.tfvars

# Values (already pre-filled):
aws_region = "us-east-1"
environment = "dev"
vpc_cidr = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24"]
private_subnet_cidrs = ["10.0.2.0/24"]
instance_type = "t2.micro"
instance_count = 1
secrets_manager_secret_name = "dev/terraform-env-vars"
# key_pair_name = "my-dev-keypair"  # Uncomment and set
```

### Step 7: Validate Configuration

```bash
# Run validation script
bash scripts/validate_deployment.sh

# Expected output:
# ✓ Terraform installed
# ✓ AWS CLI configured
# ✓ Directory structure valid
# ✓ All files present
# ✓ AWS credentials valid
# ✓ Terraform configuration valid
```

---

## PHASE 2: MANUAL TERRAFORM DEPLOYMENT (Test Locally)

### Step 8: Initialize Terraform

```bash
# Navigate to dev environment
cd env/dev

# Initialize Terraform
terraform init

# Output:
# - Terraform initialized in .terraform/
# - Downloaded AWS provider v5.x
# - Downloaded modules

# Verify
ls -la
# Should show: .terraform/, .terraform.lock.hcl
```

### Step 9: Validate Configuration

```bash
# Validate syntax
terraform validate

# Output should be:
# Success! The configuration is valid.
```

### Step 10: Review Plan

```bash
# Generate execution plan
terraform plan -out=tfplan_dev

# This shows:
# + aws_vpc.main
# + aws_subnet.public[0]
# + aws_subnet.private[0]
# + aws_internet_gateway.main
# + aws_route_table.public
# + aws_security_group.main
# + aws_instance.main[0]
# + aws_secretsmanager_secret.main

# Review the output carefully!
# Total resources to create: ~12

# Save to file for review
terraform show tfplan_dev > tfplan_output.txt
cat tfplan_output.txt
```

### Step 11: Apply Configuration

```bash
# Apply the plan
terraform apply tfplan_dev

# Terraform will:
# 1. Create VPC
# 2. Create Subnets
# 3. Create Internet Gateway
# 4. Create Route Tables
# 5. Create Security Group
# 6. Launch EC2 Instance
# 7. Create Secrets Manager secret
# 8. Run user_data script (Apache2 installation)

# Wait 2-3 minutes for resources to be created
# Output will show:
# Apply complete! Resources added: 12
```

### Step 12: Retrieve Outputs

```bash
# Get all outputs
terraform output

# Output:
# vpc_id = "vpc-0a1b2c3d4e5f6g7h8"
# public_subnet_ids = ["subnet-0x1y2z3w4v5u6t7s8"]
# private_subnet_ids = ["subnet-0a1b2c3d4e5f6g7h8"]
# web_security_group_id = "sg-0a1b2c3d4e5f6g7h8"
# web_server_instance_ids = ["i-0a1b2c3d4e5f6g7h8"]
# web_server_public_ips = ["54.123.45.67"]
# web_server_private_ips = ["10.0.1.100"]
# app_secrets_id = "dev-app-secrets"
# app_secrets_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:dev-app-secrets"

# Save outputs to variable
PUBLIC_IP=$(terraform output -raw web_server_public_ips | jq -r '.[0]')
INSTANCE_ID=$(terraform output -raw web_server_instance_ids | jq -r '.[0]')
```

### Step 13: Verify Infrastructure

```bash
# 1. Test Apache2 is running
curl http://<PUBLIC_IP>

# Expected output:
# <!DOCTYPE html>
# <html>
# <head>
#     <title>Apache Server Running</title>
# ...

# 2. SSH to instance
ssh -i ~/.ssh/my-dev-keypair.pem ubuntu@<PUBLIC_IP>

# Once connected:
# Check Apache status
sudo systemctl status apache2

# Check logs
sudo tail -f /var/log/apache2/access.log

# View web root
curl localhost

# Exit
exit
```

### Step 14: Check AWS Console

```bash
# Verify resources in AWS Console:

# 1. VPC Dashboard
# - VPC: vpc-0a1b2c3d4e5f6g7h8 (10.0.0.0/16)
# - Subnets: 2 (1 public, 1 private)
# - Internet Gateway: attached
# - Route Tables: 1 public route table

# 2. EC2 Dashboard
# - Instances: 1 running (t2.micro)
# - Instance ID: i-0a1b2c3d4e5f6g7h8
# - Public IP: 54.123.45.67
# - Security Group: web-sg (HTTP, HTTPS, SSH allowed)

# 3. Secrets Manager
# - Secret: dev/terraform-env-vars
# - Status: Available

# 4. Test web access
# Browser: http://54.123.45.67
# Should show Apache health check page
```

---

## PHASE 3: JENKINS PIPELINE DEPLOYMENT

### Step 15: Jenkins Setup

```bash
# 1. Install Jenkins (if not already installed)
# https://www.jenkins.io/download/

# 2. Start Jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins

# 3. Access Jenkins
# Browser: http://localhost:8080

# 4. Unlock Jenkins
cat /var/lib/jenkins/secrets/initialAdminPassword
# Copy and paste the key
```

### Step 16: Install Jenkins Plugins

```
Jenkins Dashboard → Manage Jenkins → Manage Plugins
```

**Required Plugins:**
- Pipeline
- Pipeline: Stage View
- Pipeline: Declarative
- Email Extension (optional)
- Git
- Credentials
- AWS Credentials

```
Search and install each plugin, then restart Jenkins
```

### Step 17: Create Jenkins Credentials

```
Jenkins Dashboard → Manage Jenkins → Manage Credentials → Global
```

#### AWS Credentials
```
- Kind: AWS Credentials
- ID: aws-credentials
- Access Key: <your-aws-access-key>
- Secret Key: <your-aws-secret-key>
- Description: AWS credentials for Terraform
```

#### GitHub Token (for private repo)
```
- Kind: Username with password
- ID: github-credentials
- Username: <your-github-username>
- Password: <your-github-token>
- Description: GitHub access token
```

#### Secrets Manager Secret
```
- Kind: Secret text
- ID: secrets-manager-secret-id
- Secret: dev/terraform-env-vars
- Description: AWS Secrets Manager secret ID
```

### Step 18: Create Jenkins Pipeline Job

```
Jenkins Dashboard → New Item
```

**Configuration:**

**General Tab:**
- Job name: `terraform-provisioning`
- Description: `Deploy Terraform infrastructure`
- Discard old builds: ✓
  - Days to keep: 30
  - Max builds: 10

**Pipeline Tab:**
- Definition: Pipeline script from SCM
- SCM: Git
  - Repository URL: (from jenkins.env)
  - Credentials: github-credentials
  - Branch: */main
  - Script Path: Jenkinsfile

**Build Triggers:**
- Poll SCM: H H * * * (daily)
- OR GitHub push hook

### Step 19: Test Pipeline - PLAN Action

```
Jenkins Dashboard → terraform-provisioning → Build with Parameters
```

**Parameters:**
- ENVIRONMENT: dev
- ACTION: PLAN
- AUTO_APPROVE: false
- AWS_REGION: us-east-1
- TERRAFORM_VERSION: 1.5.0

**Click: Build**

**Expected Pipeline Stages:**
```
1. Checkout ✓
2. Pre-Validation ✓
3. Terraform Init ✓
4. Terraform Validate ✓
5. Terraform Format Check ✓
6. Terraform Plan ✓
7. Review Plan ✓
8. Output Artifacts ✓
```

**Review Output:**
- Jenkins console shows terraform plan
- No resources created
- Artifacts saved

### Step 20: Test Pipeline - APPLY Action

```
Jenkins Dashboard → terraform-provisioning → Build with Parameters
```

**Parameters:**
- ENVIRONMENT: dev
- ACTION: APPLY
- AUTO_APPROVE: false
- AWS_REGION: us-east-1

**Click: Build**

**Approval Step:**
When Jenkins reaches "Approval" stage:
```
Jenkins shows:
╔═══════════════════════════════════════════════════════╗
║  TERRAFORM APPLY - REQUIRES APPROVAL                  ║
║                                                       ║
║  Environment: DEV                                    ║
║  Action: Apply Infrastructure Changes                ║
║  Timestamp: 20260115_143022                          ║
║                                                       ║
║  Review the plan output above and approve            ║
╚═══════════════════════════════════════════════════════╝

Click: APPROVE & APPLY
```

**Pipeline Continues:**
```
7. Approval ✓ (User approved)
8. Terraform Apply ✓
9. Output Artifacts ✓
10. State Backup ✓
```

**Result:**
```
- Infrastructure deployed in AWS
- Jenkins outputs all IPs and resource IDs
- Can now access web server
```

### Step 21: Verify via Jenkins

```bash
# In Jenkins job → Build #1 → Artifacts
# Download:
- terraform_outputs_*.json
- deployment_summary_*.txt

# Or view in Jenkins console output (last 50 lines):
VPC ID: vpc-0a1b2c3d4e5f6g7h8
Public Subnets: ["subnet-0x1y2z3w4v5u6t7s8"]
Instance IDs: ["i-0a1b2c3d4e5f6g7h8"]
Public IPs: ["54.123.45.67"]
```

---

# PREREQUISITES CHECKLIST

## Local Machine Requirements

```
✓ Terraform >= 1.5.0
  - Installation: brew install terraform (macOS) or download from hashicorp.com
  - Verify: terraform version

✓ AWS CLI v2
  - Installation: curl + unzip from awscli.amazonaws.com
  - Verify: aws --version

✓ Git
  - Installation: brew install git (macOS) or apt-get install git (Linux)
  - Verify: git --version

✓ Text Editor
  - VS Code, Vim, or any text editor
  - For editing terraform.tfvars, jenkins.env

✓ SSH Client
  - Built-in on macOS/Linux
  - PuTTY on Windows
  - For EC2 access

✓ curl / wget
  - For downloading files
  - Built-in on most systems
```

## AWS Account Requirements

```
✓ AWS Account
  - With billing enabled
  - Access to us-east-1 region (configurable)

✓ IAM User (terraform-user)
  - With Programmatic Access enabled
  - Access Key ID & Secret Access Key generated
  - Policies attached: EC2, VPC, Secrets Manager, IAM PassRole

✓ EC2 Key Pair
  - Created: aws ec2 create-key-pair --key-name my-dev-keypair
  - Saved: ~/.ssh/my-dev-keypair.pem
  - Permissions: chmod 400

✓ Secrets Manager Secret
  - Created: aws secretsmanager create-secret --name dev/terraform-env-vars
  - Contains JSON with environment variables
  - Accessible from Terraform

✓ Free Tier Eligibility (optional)
  - t2.micro EC2 instance
  - 750 hours/month free
  - VPC, storage, data transfer free
```

## Jenkins Server Requirements

```
✓ Jenkins 2.350+
  - Installation: https://www.jenkins.io/download/
  - Running on port 8080 or configured port
  - Accessible to git repository

✓ Java 11+
  - Required for Jenkins
  - Verify: java -version

✓ Plugins Installed:
  - Pipeline
  - Pipeline: Stage View
  - Pipeline: Declarative
  - Git
  - Credentials
  - AWS Credentials
  - Email Extension (optional)

✓ System Tools:
  - Terraform 1.5.0+
  - AWS CLI v2
  - Git
  - Bash shell
  - 2GB+ RAM for Jenkins

✓ Jenkins Credentials Created:
  - aws-credentials (AWS Access Key + Secret)
  - github-credentials (GitHub username + token)
  - secrets-manager-secret-id (Secret name)

✓ Jenkins Job Configured:
  - Pipeline job created
  - Pipeline script from SCM
  - Git repository URL set
  - Branch specified
  - Jenkinsfile location set
```

## Repository Requirements

```
✓ Git Repository
  - Public or private (configure credentials)
  - Contains all files from Terraform-project/
  - Jenkinsfile in root directory
  - jenkins.env configured with values

✓ Configuration Files Updated:
  - jenkins.env → GIT_REPO_URL, AWS_REGION, etc.
  - env/dev/terraform.tfvars → aws_region, vpc_cidr, etc.
  - .gitignore → excludes state files, tfvars, credentials

✓ Modules Present:
  - modules/networking/vpc/
  - modules/networking/security_group/
  - modules/compute/ec2/
  - modules/secrets/secret_manager/

✓ Scripts Present:
  - scripts/install_apache2.sh
  - scripts/validate_deployment.sh
  - scripts/load_jenkins_config.sh
```

## Network Requirements

```
✓ Internet Connectivity
  - For accessing AWS APIs
  - For accessing Terraform Registry
  - For accessing GitHub

✓ Firewall Rules
  - Jenkins server can reach AWS API (port 443)
  - Jenkins server can reach GitHub (port 443)
  - Jenkins agent can reach GitHub (port 443)

✓ Port Access:
  - Jenkins: 8080 (internal)
  - HTTP: 80 (for EC2)
  - HTTPS: 443 (for EC2)
  - SSH: 22 (for EC2 access)
```

---

# TROUBLESHOOTING

## Terraform Init Fails
```bash
Error: Failed to download module

Solution:
1. Check internet connectivity
2. Delete .terraform/ directory
3. Run: terraform init -upgrade
4. Check terraform registry availability
```

## AWS Credentials Error
```bash
Error: The AWS Access Key Id you provided does not exist

Solution:
1. Verify AWS_ACCESS_KEY_ID: aws sts get-caller-identity
2. Check IAM user permissions
3. Recreate credentials if needed
4. Update aws configure
```

## Terraform Apply Hangs
```bash
Error: Creating timeout waiting for subnet

Solution:
1. Check AWS service status
2. Verify VPC CIDR doesn't conflict
3. Check subnet availability in region
4. Increase timeout: terraform apply -timeout=10m
```

## EC2 Instance Not Responding
```bash
Error: Cannot SSH to instance

Solution:
1. Verify security group allows SSH (22)
2. Check public IP is assigned
3. Verify key pair matches
4. Check instance status in EC2 dashboard
5. Review cloud-init logs: cat /var/log/cloud-init-output.log
```

## Jenkins Approval Never Completes
```bash
Error: Approval stage stuck

Solution:
1. Check Jenkins email configuration
2. Verify approver user exists
3. Check Jenkins system logs
4. Increase timeout: timeout(time: 60, unit: 'MINUTES')
5. Manually approve: Jenkins UI → Input
```

---

# SUMMARY

## Total Deployment Time
- **Local Validation:** 5-10 minutes
- **Manual Terraform Deploy:** 15-20 minutes (including user_data)
- **Jenkins Setup:** 30-45 minutes (one-time)
- **Jenkins Pipeline Deploy:** 10-15 minutes (includes approval)

## Resources Created
- 1 VPC with CIDR 10.0.0.0/16
- 1 Public Subnet with CIDR 10.0.1.0/24
- 1 Private Subnet with CIDR 10.0.2.0/24
- 1 Internet Gateway
- 1 Route Table (public)
- 1 Security Group (HTTP, HTTPS, SSH)
- 1 EC2 Instance (t2.micro, Ubuntu 22.04 LTS, Apache2)
- 1 Secrets Manager Secret

## Estimated AWS Cost (Free Tier)
- EC2 t2.micro: Free (750 hours/month)
- VPC, Subnets, IGW: Free
- Data Transfer: Free (up to limits)
- Security Groups: Free
- **Total Monthly:** ~$0 (within free tier)

## Access Points
- Jenkins: http://jenkins-server:8080
- Web Server: http://<public-ip>
- SSH: ssh -i ~/.ssh/key.pem ubuntu@<public-ip>
- AWS Console: https://console.aws.amazon.com
