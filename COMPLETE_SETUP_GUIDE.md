# Complete Infrastructure Setup - From Scratch to AWS Deployment

## Understanding the Big Picture

### The Complete Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        YOUR COMPUTER / LAPTOP                            │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ 1. Install Tools                                                 │   │
│  │    - Terraform (Infrastructure as Code)                          │   │
│  │    - AWS CLI (AWS command line)                                  │   │
│  │    - Git (Version control)                                       │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                 │                                         │
│                                 ▼                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ 2. Create AWS Credentials                                        │   │
│  │    - AWS Account setup                                           │   │
│  │    - Create IAM User (terraform-user)                            │   │
│  │    - Generate Access Key & Secret Key                           │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                 │                                         │
│                                 ▼                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ 3. Configure AWS CLI                                             │   │
│  │    - Run: aws configure                                          │   │
│  │    - Enter Access Key, Secret Key, Region                       │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                 │                                         │
│                                 ▼                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ 4. Create GitHub Repository                                      │   │
│  │    - Push this Terraform code to GitHub                          │   │
│  │    - Make it accessible to Jenkins                               │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                 │                                         │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
        ┌─────────────────────────────────────────────────┐
        │      GITHUB REPOSITORY                          │
        │  (Your Terraform code lives here)               │
        │  - Jenkinsfile (instructions for Jenkins)       │
        │  - jenkins.env (configuration)                  │
        │  - env/dev/ (dev environment config)            │
        │  - modules/ (reusable components)               │
        └─────────────────────────────────────────────────┘
                        ▲           │
                        │           │
                        │           ▼
                  (1. Pull)    ┌─────────────────────────────────────────────────┐
                  (2. Watch)   │          JENKINS SERVER                         │
                        │      │  (Automated Deployment Machine)                 │
                        │      │                                                 │
                        │      │  ┌─────────────────────────────────┐            │
                        │      │  │ 1. Watches GitHub for changes   │            │
                        │      │  │ 2. Pulls latest code            │            │
                        │      │  │ 3. Runs Terraform commands:     │            │
                        │      │  │    - terraform init             │            │
                        │      │  │    - terraform plan             │            │
                        │      │  │    - terraform apply            │            │
                        │      │  │ 4. Uses AWS credentials         │            │
                        │      │  │ 5. Sends resources to AWS       │            │
                        │      │  └─────────────────────────────────┘            │
                        └──────└─────────────────────────────────────────────────┘
                                  │
                                  ▼
        ┌─────────────────────────────────────────────────┐
        │        AWS CLOUD (YOUR INFRASTRUCTURE)          │
        │                                                 │
        │  Resources Created:                            │
        │  ✓ VPC (Virtual Private Cloud)                │
        │  ✓ Subnets (Public & Private)                 │
        │  ✓ Internet Gateway                            │
        │  ✓ EC2 Instance (Web Server)                   │
        │  ✓ Security Groups (Firewall rules)            │
        │  ✓ Secrets Manager (Password storage)          │
        │                                                 │
        │  Result: Apache2 Web Server Running!           │
        └─────────────────────────────────────────────────┘
```

---

## Prerequisites - DETAILED BREAKDOWN

### CATEGORY 1: Tools Installation (On Your Computer)

#### 1.1 Terraform

**What is it?**
- Software that reads `.tf` files and creates AWS resources
- Turns code into real infrastructure
- Like a recipe for building servers

**Installation Steps:**

```bash
# macOS
brew install terraform

# Linux (Ubuntu)
wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
unzip terraform_1.5.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Windows
# Download from: https://www.hashicorp.com/products/terraform/downloads
# Or use: choco install terraform

# Verify installation
terraform version

# Output should show:
# Terraform v1.5.0 on linux_amd64
```

**Current Setup Usage:**
- Reads our `.tf` files in `env/dev/`
- Creates resources defined in `modules/`
- Manages AWS infrastructure

---

#### 1.2 AWS CLI v2

**What is it?**
- Command line tool to interact with AWS
- Lets you manage AWS resources from terminal
- Needed for authentication and configuration

**Installation Steps:**

```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Windows
# Download from: https://aws.amazon.com/cli/

# Verify installation
aws --version

# Output should show:
# aws-cli/2.13.x
```

**Current Setup Usage:**
- Stores AWS credentials locally
- Terraform uses it to authenticate with AWS
- Can manually verify AWS resources

---

#### 1.3 Git

**What is it?**
- Version control system
- Tracks code changes
- Pushes code to GitHub

**Installation Steps:**

```bash
# macOS
brew install git

# Linux
sudo apt-get install git

# Windows
# Download from: https://git-scm.com/

# Verify installation
git --version

# Output should show:
# git version 2.41.0
```

**Current Setup Usage:**
- Clone this repository locally
- Push changes to GitHub
- Jenkins pulls code from GitHub

---

### CATEGORY 2: AWS Account Setup

#### 2.1 Create AWS Account

**Steps:**

```
1. Go to: https://aws.amazon.com/
2. Click "Create an AWS Account"
3. Enter email, password, account name
4. Add payment method (credit/debit card)
5. Verify email
6. Complete identity verification
```

**Time:** ~15 minutes

**Cost:** Free tier eligible (no charges first year for our resources)

---

#### 2.2 Create IAM User for Terraform

**What is IAM?**
- Identity and Access Management
- Controls who can access what in AWS
- Security best practice: Don't use root account

**Steps:**

```
AWS Console → Services → IAM → Users
```

**Step-by-step:**

```
1. Click "Create user"
2. User name: terraform-user
3. Check: "Provide user access to the AWS Management Console"
4. Click "Next"
5. Attach policies:
   - Search: "PowerUserAccess"
   - Check the box
   - Click "Next"
6. Click "Create user"
```

**After Creation:**

```
1. User created: terraform-user
2. Note the 12-digit AWS Account ID (shown on page)
3. Keep this safe!
```

---

#### 2.3 Generate Access Keys

**What are Access Keys?**
- Like username & password for Terraform
- Used for authentication
- **KEEP THEM SECRET** (don't share!)

**Steps:**

```
AWS Console → IAM → Users → terraform-user
```

**In the user details page:**

```
1. Click "Security credentials" tab
2. Scroll to "Access keys"
3. Click "Create access key"
4. Select: "Command Line Interface (CLI)"
5. Click "Next"
6. Click "Create access key"
7. **SAVE BOTH KEYS IMMEDIATELY:**
   - Access Key ID: AKIA...
   - Secret Access Key: wJalr...
   (You can only see secret key once!)
```

**If you miss saving:**

```
You can delete and create new ones
AWS Console → IAM → Users → terraform-user → Create access key
```

---

#### 2.4 Create Secrets Manager Secret (For Environment Variables)

**What is it?**
- Secure storage for passwords and API keys
- Our Terraform code reads from here
- Better than hardcoding passwords

**Steps:**

```bash
# Run from your computer (with AWS CLI configured)
aws secretsmanager create-secret \
  --name dev/terraform-env-vars \
  --region us-east-1 \
  --secret-string '{
    "db_password": "my-secure-password",
    "api_key": "my-api-key",
    "environment": "development"
  }'
```

**Verify it was created:**

```bash
aws secretsmanager describe-secret \
  --secret-id dev/terraform-env-vars \
  --region us-east-1

# Output:
# {
#     "ARN": "arn:aws:secretsmanager:...",
#     "Name": "dev/terraform-env-vars",
#     "Status": "Available"
# }
```

---

#### 2.5 Create EC2 Key Pair (For SSH Access)

**What is it?**
- Used to SSH (securely login) to EC2 instances
- Private key (keep safe) + Public key (stored on AWS)
- Like a lock & key pair

**Steps:**

```bash
# Create key pair
aws ec2 create-key-pair \
  --key-name my-dev-keypair \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/my-dev-keypair.pem

# Set permissions (IMPORTANT!)
chmod 400 ~/.ssh/my-dev-keypair.pem

# Verify it was created
aws ec2 describe-key-pairs --region us-east-1

# Output:
# {
#     "KeyPairs": [
#         {
#             "KeyName": "my-dev-keypair",
#             "KeyType": "rsa"
#         }
#     ]
# }
```

**Save location:** `~/.ssh/my-dev-keypair.pem`

**Why permissions?** AWS requires read-only: `chmod 400`

---

### CATEGORY 3: Local Computer Configuration

#### 3.1 Configure AWS CLI

**What it does:**
- Stores your AWS credentials locally
- Terraform reads these credentials
- Used for authentication

**Steps:**

```bash
# Run this command
aws configure

# You'll be prompted:
# AWS Access Key ID [None]: AKIA...
# (Paste your Access Key ID from step 2.3)

# AWS Secret Access Key [None]: wJalr...
# (Paste your Secret Access Key from step 2.3)

# Default region name [None]: us-east-1
# (Type: us-east-1)

# Default output format [None]: json
# (Type: json)
```

**Verify it worked:**

```bash
aws sts get-caller-identity

# Output should show:
# {
#     "UserId": "AIDA...",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/terraform-user"
# }

# If you see this, AWS CLI is configured correctly!
```

**Where credentials are stored:**

```bash
# Credentials file (don't edit manually)
cat ~/.aws/credentials

# Config file
cat ~/.aws/config
```

---

#### 3.2 Clone This Repository

**Steps:**

```bash
# Create a projects directory
mkdir ~/projects
cd ~/projects

# Clone the repository
git clone https://github.com/your-org/terraform-project.git

# Navigate into it
cd terraform-project

# See the structure
tree -L 2

# Output should show:
# terraform-project/
# ├── Jenkinsfile
# ├── jenkins.env
# ├── env/
# ├── modules/
# ├── scripts/
# └── ...
```

**Verify everything is there:**

```bash
ls -la

# You should see:
# Jenkinsfile, jenkins.env, README.md, DEPLOYMENT_STEPS.md
# env/ directory, modules/ directory, scripts/ directory
```

---

#### 3.3 Update Configuration Files

**File 1: jenkins.env**

**Location:** `terraform-project/jenkins.env`

**What to update:**

```bash
# Edit the file
vim jenkins.env

# Change these lines:

# YOUR GITHUB REPOSITORY URL
GIT_REPO_URL=https://github.com/YOUR-USERNAME/terraform-project.git

# YOUR GITHUB BRANCH
GIT_BRANCH=*/main

# AWS REGION (closest to you)
AWS_REGION=us-east-1

# TERRAFORM VERSION (don't change unless needed)
TERRAFORM_VERSION=1.5.0
```

**Why?** Jenkins will read these values to know where to find your code.

---

**File 2: env/dev/terraform.tfvars**

**Location:** `terraform-project/env/dev/terraform.tfvars`

**Current values (already good, but understand them):**

```bash
# Edit the file
vim env/dev/terraform.tfvars

# These values should match your setup:

aws_region = "us-east-1"  # Where to create resources
environment = "dev"        # Environment name

# VPC CIDR block (IP range for your network)
vpc_cidr = "10.0.0.0/16"

# Public subnet (internet-accessible)
public_subnet_cidrs = ["10.0.1.0/24"]

# Private subnet (no internet access)
private_subnet_cidrs = ["10.0.2.0/24"]

# EC2 instance specs
instance_type = "t2.micro"      # Free tier eligible
instance_count = 1              # Single instance
root_volume_size = 20           # 20 GB disk

# This must match the secret you created in step 2.4!
secrets_manager_secret_name = "dev/terraform-env-vars"

# OPTIONAL: Key pair name (uncomment if you created one)
# key_pair_name = "my-dev-keypair"
```

**Key Point:** The `secrets_manager_secret_name` MUST match what you created in step 2.4!

---

### CATEGORY 4: GitHub Setup

#### 4.1 Create GitHub Account

**Steps:**

```
1. Go to: https://github.com/
2. Click "Sign up"
3. Enter email, password, username
4. Verify email
5. Done!
```

---

#### 4.2 Create GitHub Repository

**Steps:**

```
GitHub → Click "+" → New repository
```

**Fill in:**

```
- Repository name: terraform-project
- Description: Terraform infrastructure as code
- Public (if Jenkins is external) or Private
- Click "Create repository"
```

**Now push your code:**

```bash
# Navigate to your project
cd ~/projects/terraform-project

# Initialize git (if not done)
git init

# Add all files
git add .

# Commit files
git commit -m "Initial Terraform infrastructure setup"

# Add remote (use the URL from GitHub)
git remote add origin https://github.com/YOUR-USERNAME/terraform-project.git

# Push to GitHub
git branch -M main
git push -u origin main

# Verify
# Go to https://github.com/YOUR-USERNAME/terraform-project
# You should see all your files there!
```

---

### CATEGORY 5: Jenkins Server Setup

#### 5.1 Install Jenkins

**What is Jenkins?**
- Automation server
- Watches GitHub for changes
- Automatically runs Terraform
- No manual commands needed

**Installation (on Linux server):**

```bash
# Option 1: Docker (easiest)
docker run -d -p 8080:8080 -p 50000:50000 jenkins/jenkins:lts

# Option 2: Direct installation
# For Ubuntu 20.04+
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt-get update
sudo apt-get install jenkins

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins
```

**Access Jenkins:**

```
Browser: http://localhost:8080
(Or http://YOUR-SERVER-IP:8080 if remote)
```

**Unlock Jenkins:**

```bash
# Get the initial password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Copy the password, paste in browser
# Then set up admin user account
```

---

#### 5.2 Install Jenkins Plugins

**Required plugins for Terraform:**

```
Jenkins Dashboard → Manage Jenkins → Manage Plugins
```

**Search and install each:**

```
1. Pipeline
2. Pipeline: Stage View
3. Pipeline: Declarative
4. Git
5. Credentials
6. AWS Credentials
7. Blue Ocean (optional, for better UI)
```

**After installation, restart Jenkins:**

```
Jenkins Dashboard → Restart Jenkins
```

---

#### 5.3 Create Jenkins Credentials

**Credential 1: AWS Credentials**

```
Jenkins → Manage Jenkins → Manage Credentials → Global → Add Credentials
```

```
- Kind: AWS Credentials
- ID: aws-credentials (IMPORTANT: exact name!)
- Access Key ID: AKIA... (from step 2.3)
- Secret Access Key: wJalr... (from step 2.3)
- Description: AWS credentials for Terraform
- Click: Create
```

**Credential 2: GitHub Token**

```
Jenkins → Manage Jenkins → Manage Credentials → Global → Add Credentials
```

```
- Kind: Username with password
- ID: github-credentials (IMPORTANT: exact name!)
- Username: YOUR-GITHUB-USERNAME
- Password: YOUR-GITHUB-TOKEN (from GitHub settings)
- Description: GitHub access token
- Click: Create
```

**How to get GitHub Token:**

```
GitHub → Settings → Developer settings → Personal access tokens
→ Tokens (classic) → Generate new token (classic)

Select scopes:
✓ repo (full control of private repositories)
✓ admin:repo_hook (full control of repository hooks)

Click: Generate token

Copy the token immediately (you can't see it again!)
Paste into Jenkins credential
```

**Credential 3: Secrets Manager Secret ID**

```
Jenkins → Manage Jenkins → Manage Credentials → Global → Add Credentials
```

```
- Kind: Secret text
- ID: secrets-manager-secret-id (IMPORTANT: exact name!)
- Secret: dev/terraform-env-vars (from step 2.4)
- Description: AWS Secrets Manager secret name
- Click: Create
```

---

#### 5.4 Create Jenkins Pipeline Job

**Steps:**

```
Jenkins Dashboard → New Item
```

**Fill in:**

```
- Job name: terraform-provisioning
- Type: Pipeline
- Click: OK
```

**Configure Job:**

```
General Tab:
- Description: Deploy Terraform infrastructure
- Discard old builds: ✓
  - Days to keep: 30
  - Max builds: 10

Pipeline Tab:
- Definition: Pipeline script from SCM
- SCM: Git
  - Repository URL: https://github.com/YOUR-USERNAME/terraform-project.git
  - Credentials: github-credentials
  - Branch: */main
  - Script Path: Jenkinsfile
  
- Click: Save
```

---

## Complete Flow Explained Step-by-Step

### FLOW DIAGRAM WITH TIMINGS

```
DAY 1: Setup (1-2 hours, one-time)
├─ Install tools (Terraform, AWS CLI, Git) .......................... 15 min
├─ Create AWS account & IAM user ...................................... 20 min
├─ Create Access Keys & store safely .................................. 5 min
├─ Configure AWS CLI locally ............................................ 5 min
├─ Create Secrets Manager secret ....................................... 5 min
├─ Create EC2 key pair ................................................. 5 min
├─ Clone repository & update configs .................................. 10 min
├─ Push to GitHub ........................................................ 5 min
├─ Install Jenkins ....................................................... 20 min
├─ Install Jenkins plugins .............................................. 10 min
├─ Create Jenkins credentials (3 of them) ............................. 15 min
└─ Create Jenkins pipeline job .......................................... 10 min

DAY 2: First Deployment (30 minutes)
├─ Test locally (optional) ............................................ 10 min
└─ Run Jenkins pipeline
   ├─ Click: Build with Parameters ..................................... 1 min
   ├─ Wait for Terraform plan .......................................... 3 min
   ├─ Review output ...................................................... 2 min
   ├─ Click: Approve & Apply ............................................ 1 min
   ├─ Wait for resources to create ..................................... 10 min
   └─ Test web server ................................................... 3 min
```

---

## REAL WORLD FLOW (What Happens When You Build)

### Step 1: You Click "Build with Parameters" in Jenkins

```
1. You open: http://jenkins-server:8080
2. Navigate to: terraform-provisioning job
3. Click: "Build with Parameters"
4. Select:
   - ENVIRONMENT: dev
   - ACTION: APPLY
   - AUTO_APPROVE: false
   - AWS_REGION: us-east-1
5. Click: "Build"
```

### Step 2: Jenkins Starts Working

```
Pipeline Stage: "Checkout"
├─ Jenkins clones your GitHub repo
├─ Gets all the Terraform files
├─ Stores them in Jenkins workspace
└─ ✓ Ready for next stage
```

### Step 3: Jenkins Validates Everything

```
Pipeline Stage: "Pre-Validation"
├─ Checks if Terraform is installed
├─ Checks if AWS CLI is installed
├─ Checks AWS credentials are valid
├─ Runs: aws sts get-caller-identity
└─ ✓ All tools working
```

### Step 4: Initialize Terraform

```
Pipeline Stage: "Terraform Init"
├─ Reads: env/dev/terraform.tfvars
├─ Reads: modules/*/
├─ Downloads AWS provider v5.0
├─ Creates: .terraform/ directory
└─ ✓ Terraform ready
```

### Step 5: Validate Configuration

```
Pipeline Stage: "Terraform Validate"
├─ Checks syntax of all .tf files
├─ Verifies variables are correct
├─ Verifies modules are valid
└─ ✓ Configuration is valid
```

### Step 6: Create Execution Plan

```
Pipeline Stage: "Terraform Plan"
├─ Reads: env/dev/terraform.tfvars
│  - aws_region = "us-east-1"
│  - vpc_cidr = "10.0.0.0/16"
│  - instance_type = "t2.micro"
│
├─ Reads: modules/networking/vpc/
├─ Reads: modules/compute/ec2/
├─ Reads: modules/networking/security_group/
├─ Reads: modules/secrets/secret_manager/
│
├─ Asks AWS: "What would I create?"
│
└─ Shows Plan:
   + aws_vpc.main (VPC 10.0.0.0/16)
   + aws_subnet.public[0] (10.0.1.0/24)
   + aws_subnet.private[0] (10.0.2.0/24)
   + aws_internet_gateway.main
   + aws_security_group.main (HTTP, HTTPS, SSH rules)
   + aws_instance.main[0] (t2.micro, Ubuntu LTS, Apache2)
   + aws_secretsmanager_secret.main (dev-app-secrets)
   
   Plan: 12 resources to add
```

### Step 7: Jenkins Shows Plan & Waits for Approval

```
Jenkins Console Output:
╔═══════════════════════════════════════════════════════╗
║  TERRAFORM APPLY - REQUIRES APPROVAL                  ║
║                                                       ║
║  Environment: DEV                                    ║
║  Action: Apply Infrastructure Changes                ║
║  Timestamp: 20260115_143022                          ║
║                                                       ║
║  Review the plan output above and approve            ║
╚═══════════════════════════════════════════════════════╝

Jenkins waits for input...
(30 minute timeout)
```

### Step 8: You Approve in Jenkins

```
Jenkins UI shows:
[APPROVE & APPLY] button

You click it!

Or Jenkins Email notifications (if enabled) with approve link
```

### Step 9: Terraform Creates Resources (5-10 minutes)

```
Jenkins Console Output:

Creating aws_vpc.main...
aws_vpc.main: Creation complete after 1s

Creating aws_subnet.public[0]...
aws_subnet.public[0]: Creation complete after 2s

Creating aws_subnet.private[0]...
aws_subnet.private[0]: Creation complete after 2s

Creating aws_internet_gateway.main...
aws_internet_gateway.main: Creation complete after 1s

Creating aws_security_group.main...
aws_security_group.main: Creation complete after 2s

Creating aws_instance.main[0]...
aws_instance.main[0]: Still creating... [1m30s elapsed]
aws_instance.main[0]: Creation complete after 2m

Creating aws_secretsmanager_secret.main...
aws_secretsmanager_secret.main: Creation complete after 1s

Apply complete! Resources added: 12
```

### Step 10: Jenkins Shows Outputs

```
Jenkins displays:

========== VPC Information ==========
VPC ID: vpc-0a1b2c3d4e5f6g7h8
Public Subnets: ["subnet-0x1y2z3w4v5u6t7s8"]
Private Subnets: ["subnet-0a1b2c3d4e5f6g7h8"]

========== EC2 Instances ==========
Instance IDs: ["i-0a1b2c3d4e5f6g7h8"]
Public IPs: ["54.123.45.67"]
Private IPs: ["10.0.1.100"]

========== Security Groups ==========
Web Security Group ID: sg-0a1b2c3d4e5f6g7h8

========== Secrets Manager ==========
App Secrets ID: dev-app-secrets

========== Next Steps ==========
1. Access the web server: http://54.123.45.67
2. SSH to instance: ssh -i ~/.ssh/my-dev-keypair.pem ubuntu@54.123.45.67
3. Check Apache status: sudo systemctl status apache2
```

### Step 11: Infrastructure is Live!

```
In AWS Console, you can see:
✓ VPC 10.0.0.0/16 created
✓ 2 Subnets created
✓ Internet Gateway attached
✓ Security Group with rules
✓ EC2 Instance running (Public IP: 54.123.45.67)
✓ Apache2 web server running

In Browser:
✓ http://54.123.45.67 shows Apache health check page

Via SSH:
✓ ssh -i ~/.ssh/my-dev-keypair.pem ubuntu@54.123.45.67
✓ Connected to EC2!
```

---

## Current Setup - What's Already Done For You

```
✓ Jenkinsfile - Written (defines all stages)
✓ jenkins.env - Template (you update with your values)
✓ env/dev/main.tf - Written (calls all modules)
✓ env/dev/variables.tf - Written (defines inputs)
✓ env/dev/terraform.tfvars - Template (you update values)
✓ modules/networking/vpc/ - Written (VPC logic)
✓ modules/networking/security_group/ - Written (SG logic)
✓ modules/compute/ec2/ - Written (EC2 logic)
✓ modules/secrets/secret_manager/ - Written (Secrets logic)
✓ scripts/install_apache2.sh - Written (Apache setup)
✓ scripts/validate_deployment.sh - Written (validation)
✓ README.md - Written (overview)
✓ DEPLOYMENT_STEPS.md - Written (detailed steps)
```

---

## Prerequisites Checklist - MINIMAL

### Before Starting ANY Deployment

```
☐ TOOLS INSTALLED:
  ☐ Terraform (terraform version shows output)
  ☐ AWS CLI (aws --version shows output)
  ☐ Git (git --version shows output)

☐ AWS ACCOUNT:
  ☐ AWS account created
  ☐ IAM user "terraform-user" created
  ☐ Access Key ID copied & saved safely
  ☐ Secret Access Key copied & saved safely

☐ LOCAL CONFIGURATION:
  ☐ AWS CLI configured (aws sts get-caller-identity works)
  ☐ Repository cloned locally
  ☐ jenkins.env updated with your GitHub URL & region
  ☐ env/dev/terraform.tfvars verified (values are correct)

☐ AWS RESOURCES:
  ☐ Secrets Manager secret created: dev/terraform-env-vars
  ☐ EC2 key pair created: my-dev-keypair
  ☐ Key pair saved to: ~/.ssh/my-dev-keypair.pem

☐ GITHUB:
  ☐ GitHub account created
  ☐ Repository created
  ☐ Code pushed to GitHub

☐ JENKINS:
  ☐ Jenkins installed & running
  ☐ Plugins installed (Pipeline, Git, AWS, Credentials)
  ☐ AWS credentials created in Jenkins
  ☐ GitHub credentials created in Jenkins
  ☐ Secrets Manager secret ID created in Jenkins
  ☐ Pipeline job created

☐ READY TO DEPLOY!
```

---

## Quick Reference: The 3-Command Deployment (After Setup)

Once everything is configured, deployment is simple:

```bash
# FROM YOUR COMPUTER (optional, test locally first):
cd env/dev
terraform init
terraform plan
terraform apply

# OR FROM JENKINS (recommended for automation):
# 1. Open Jenkins: http://localhost:8080
# 2. Click: terraform-provisioning → Build with Parameters
# 3. Select: ENVIRONMENT=dev, ACTION=APPLY
# 4. Click: Build
# 5. Wait for approval stage
# 6. Click: APPROVE & APPLY
# 7. Watch resources get created!
```

---

## Common Questions

### Q: Why do I need Jenkins if I can run Terraform locally?
**A:** Jenkins automates it! You can push code to GitHub, Jenkins automatically deploys. No manual commands needed.

### Q: What if I don't have AWS credentials?
**A:** You can't provision anything without AWS. Must create IAM user first (free).

### Q: Can I use a different region?
**A:** Yes! Change `aws_region` in `env/dev/terraform.tfvars`. Also update Jenkins variables if different.

### Q: What if the EC2 instance doesn't start?
**A:** Check:
1. Security group allows SSH (port 22)
2. Key pair exists in AWS
3. Cloud-init logs: `cat /var/log/cloud-init-output.log` on EC2
4. AWS Console → EC2 → Instance status checks

### Q: Can I deploy to multiple environments?
**A:** Yes! Copy `env/dev/` to `env/stage/`, update terraform.tfvars, run pipeline with ENVIRONMENT=stage

### Q: What if Jenkins credentials are wrong?
**A:** Delete and recreate them. Jenkins → Manage Credentials → Delete → Create new one with exact ID

### Q: How do I destroy everything?
**A:** Jenkins → Build with Parameters → ACTION=DESTROY → Confirm twice → All resources deleted

---

## SUMMARY: What You Have

```
A Complete Infrastructure-as-Code Setup Including:

1. TERRAFORM:
   - Reusable modules (VPC, EC2, Security Group, Secrets)
   - Dev environment configuration
   - Fully parameterized (no hardcoding)

2. JENKINS:
   - Declarative pipeline
   - Multi-environment support (dev/stage)
   - Manual approval workflow
   - No hardcoded values

3. GITHUB:
   - Version controlled infrastructure
   - Easy collaboration
   - Jenkins integration ready

4. AWS:
   - Live web server with Apache2
   - Secure networking (VPC, subnets, IGW)
   - Access control (security groups)
   - Secret management (Secrets Manager)

5. DOCUMENTATION:
   - Step-by-step guides
   - Troubleshooting tips
   - Best practices
   - Prerequisites checklist
```

**YOU'RE READY TO BUILD INFRASTRUCTURE LIKE A PRO!** 🚀
