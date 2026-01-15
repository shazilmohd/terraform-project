# Jenkins Pipeline Setup Guide

## Overview

This guide explains how to set up and configure a Jenkins declarative pipeline for provisioning the Terraform infrastructure in the dev environment.

---

## Prerequisites

### Jenkins Setup
- Jenkins 2.350+ installed
- Pipeline plugin installed
- Credentials plugin installed
- Email Extension plugin (optional, for notifications)
- Git plugin installed

### Required Jenkins Plugins
```
- Pipeline: Declarative Agent API
- Pipeline: Stage View
- Pipeline: Basic Steps
- Email Extension Plugin (for notifications)
- Pipeline: Groovy
- Git plugin
```

### System Requirements
- Terraform 1.5.0+
- AWS CLI v2
- Git
- Bash shell
- 2GB+ RAM (for Jenkins agent)

---

## Jenkins Configuration

### 1. Create Jenkins Configuration File

**Location:** `jenkins.env` (at repository root)

This file contains all configurable parameters. Example:

```bash
# Git Configuration
GIT_REPO_URL=https://github.com/your-org/terraform-project.git
GIT_BRANCH=*/main

# Jenkins Configuration
JENKINS_APPROVERS=terraform-approvers
JENKINS_NOTIFY_EMAIL=devops-team@example.com

# AWS Configuration
AWS_REGION=us-east-1
AWS_CREDENTIALS_ID=aws-credentials
SECRETS_MANAGER_CREDENTIALS_ID=secrets-manager-secret-id

# Terraform Configuration
TERRAFORM_VERSION=1.5.0
TF_LOG_LEVEL=INFO

# Supported Environments
SUPPORTED_ENVIRONMENTS=dev,stage
```

**Update in jenkins.env:**
```bash
GIT_REPO_URL=https://github.com/your-org/terraform-project.git
GIT_BRANCH=*/main
JENKINS_APPROVERS=terraform-approvers
JENKINS_NOTIFY_EMAIL=devops-team@example.com
AWS_REGION=us-east-1
```

### 2. Create Jenkins Credentials

#### AWS Credentials (Secret Access Key)

```
Jenkins Dashboard → Manage Jenkins → Manage Credentials → Global → Add Credentials
```

**Fill in the following:**
- Kind: `AWS Credentials`
- ID: `aws-credentials`
- Access Key ID: `<your-aws-access-key>`
- Secret Access Key: `<your-aws-secret-key>`
- Description: `AWS credentials for Terraform provisioning`

#### Secrets Manager Secret ID

```
Jenkins Dashboard → Manage Jenkins → Manage Credentials → Global → Add Credentials
```

**Fill in the following:**
- Kind: `Secret text`
- ID: `secrets-manager-secret-id`
- Secret: `dev/terraform-env-vars`
- Description: `AWS Secrets Manager secret ID for dev environment`

#### GitHub Token (if using private repo)

```
Jenkins Dashboard → Manage Jenkins → Manage Credentials → Global → Add Credentials
```

**Fill in the following:**
- Kind: `Username with password` or `SSH Username with private key`
- ID: `github-credentials`
- Username: `<your-github-username>`
- Password: `<your-github-token>`
- Description: `GitHub credentials for repository access`

---

### 2. Create Jenkins Job

#### Step 1: Create New Pipeline Job

```
Jenkins Dashboard → New Item → Enter job name (e.g., "terraform-dev-provisioning")
Choose → Pipeline → Click OK
```

#### Step 2: Configure Pipeline

In the job configuration page:

**General Tab:**
- Check: `Discard old builds`
  - Days to keep builds: 30
  - Max builds to keep: 10

**Build Triggers:**
- Option 1: `Poll SCM` (e.g., `H H * * *` for daily)
- Option 2: `GitHub hook trigger for GITScm polling`
- Option 3: Manual trigger (default)

**Pipeline Tab:**

**Definition:** Pipeline script from SCM

**SCM:** Git
- Repository URL: `https://github.com/your-org/terraform-project.git`
- Credentials: Select `github-credentials`
- Branch Specifier: `*/main`
- Script Path: `Jenkinsfile`

---

### 3. Configure Environment Variables

In the Jenkinsfile, update these environment variables:

```groovy
environment {
    GIT_REPO_URL = 'https://github.com/your-org/terraform-project.git'
    JENKINS_NOTIFY_EMAIL = 'devops-team@example.com'
    // Other variables are already set in the Jenkinsfile
}
```

Or set them in Jenkins Job Configuration → Build Environment:

```
Key: GIT_REPO_URL
Value: https://github.com/your-org/terraform-project.git

Key: JENKINS_NOTIFY_EMAIL
Value: devops-team@example.com
```

---

### 4. Configure Email Notifications (Optional)

**Jenkins System Configuration:**

```
Jenkins Dashboard → Manage Jenkins → System Configuration
```

**E-mail Notification:**
- SMTP server: `smtp.gmail.com` or your mail server
- Default user e-mail suffix: `@example.com`
- Use SMTP Authentication: ✓
- Use TLS: ✓
- SMTP Port: 587

**Extended E-mail Notification:**
- SMTP server: (same as above)
- Default user e-mail suffix: `@example.com`

---

## Running the Pipeline

### Method 1: Manual Trigger

1. Go to Jenkins Dashboard
2. Click on your job: `terraform-dev-provisioning`
3. Click `Build with Parameters`
4. Select parameters:
   - ACTION: Choose `PLAN`, `APPLY`, or `DESTROY`
   - AUTO_APPROVE: Check if you want to skip approval (not recommended for production)
   - TERRAFORM_VERSION: Default is fine, or change to specific version
5. Click `Build`

### Method 2: GitOps (Webhook)

**For GitHub:**

1. In your GitHub repository settings:
   - Settings → Webhooks → Add webhook
   - Payload URL: `http://jenkins.example.com/github-webhook/`
   - Events: Push events
   - Active: ✓

2. Jenkins will automatically trigger on push to main branch

---

## Pipeline Stages Explained

### 1. **Checkout**
- Clones the repository from GitHub
- Uses credentials from Jenkins secrets

### 2. **Pre-Validation**
- Verifies Terraform and AWS CLI are installed
- Checks AWS credentials are valid
- Validates directory structure

### 3. **Terraform Init**
- Initializes Terraform working directory
- Downloads required providers and modules
- Creates `.terraform` directory

### 4. **Terraform Validate**
- Validates Terraform configuration syntax
- Checks variable types and required values
- Validates module references

### 5. **Terraform Format Check**
- Ensures consistent code formatting
- Validates HCL syntax standards

### 6. **Terraform Plan**
- Generates execution plan
- Shows what resources will be created/modified/deleted
- Saves plan file for later apply

### 7. **Review Plan**
- Displays plan summary
- Last chance to review before approval

### 8. **Approval** (Manual Step)
- Requires human approval before apply
- Can skip with `AUTO_APPROVE=true` (not recommended)
- 30-minute timeout for approval

### 9. **Terraform Apply**
- Executes the plan
- Creates/updates/deletes AWS resources
- Updates `terraform.tfstate`

### 10. **Terraform Destroy** (if ACTION=DESTROY)
- Requires explicit confirmation
- Deletes all AWS resources
- **Irreversible!**

### 11. **Output Artifacts**
- Extracts and displays outputs
- Creates human-readable deployment summary
- Archives artifacts for reference

### 12. **State Backup**
- Backs up terraform.tfstate file
- Prevents accidental loss of state

---

## Pipeline Parameters

### ACTION
- **PLAN**: Generate execution plan (read-only)
- **APPLY**: Apply the plan (creates/updates resources)
- **DESTROY**: Delete all resources

### AUTO_APPROVE
- **false** (default): Requires manual approval for apply
- **true**: Skips approval (use with caution)

### TERRAFORM_VERSION
- Default: `1.5.0`
- Can be changed to any available version

---

## Monitoring Pipeline Execution

### View Pipeline Progress
1. Click on job in Jenkins Dashboard
2. Click on the latest build number
3. View real-time console output

### View Test Results
- Pipeline automatically archives artifacts
- Accessed via: Job → Build → Artifacts

### Troubleshooting
- Check console output for error messages
- Review terraform logs (TF_LOG=INFO)
- Verify AWS credentials and permissions
- Check Secrets Manager secret exists

---

## Security Best Practices

### 1. **Access Control**
```groovy
submitter: 'terraform-approvers'  // Only certain users can approve
```

Edit Jenkins job to restrict approvers:
- Configure project → Build Triggers → Restrict to specific nodes

### 2. **Credential Management**
- Use Jenkins credentials vault (not hardcoded)
- Rotate AWS access keys regularly
- Use IAM roles when possible (for EC2 agents)

### 3. **Audit Logging**
- Jenkins logs all pipeline executions
- Pipeline code is versioned in Git
- Use Jenkins audit logging plugin for compliance

### 4. **Approval Workflow**
- Always require approval for apply/destroy
- Set approval timeout appropriately
- Restrict approvers to authorized personnel

### 5. **Environment Isolation**
- Separate Jenkins pipelines for dev/stage/prod
- Use different AWS accounts if possible
- Different Secrets Manager secrets per environment

---

## Troubleshooting Common Issues

### Issue 1: "AWS credentials not found"
**Solution:**
```bash
# Verify credentials are created in Jenkins
# Check Jenkins console output for AWS CLI errors
aws sts get-caller-identity  # Test manually
```

### Issue 2: "Terraform init fails"
**Solution:**
```bash
# Check network connectivity to Terraform registry
# Verify SSH key for Git (if using SSH)
terraform init -upgrade
```

### Issue 3: "Approval stage hangs"
**Solution:**
- Check Jenkins notification settings
- Verify approver user exists and has permissions
- Check Jenkins user authentication

### Issue 4: "State file lock error"
**Solution:**
```bash
# Release stuck state lock
cd env/dev
terraform force-unlock <LOCK_ID>
```

### Issue 5: "EC2 instances not getting public IPs"
**Solution:**
```bash
# Check security group allows HTTP/HTTPS
# Verify subnet has public route table
# Check Auto-assign Public IP setting
```

---

## Advanced Configurations

### Using Remote State (S3 Backend)

Create `env/dev/backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### Slack Notifications

Add to Jenkinsfile post section:
```groovy
post {
    success {
        slackSend(
            channel: '#terraform-notifications',
            color: 'good',
            message: "Terraform ${params.ACTION} SUCCESS\nBuild: ${BUILD_URL}"
        )
    }
}
```

### Pre-commit Hooks

Add Git pre-commit hook to validate before push:
```bash
#!/bin/bash
# .git/hooks/pre-commit
cd env/dev
terraform validate
terraform fmt -check
```

---

## Deployment Checklist

Before triggering the pipeline:

- [ ] Reviewed `env/dev/terraform.tfvars` values
- [ ] Confirmed AWS Secrets Manager secret exists
- [ ] Checked AWS IAM permissions for Terraform user
- [ ] Verified EC2 key pair exists in AWS
- [ ] Reviewed security group rules
- [ ] Backed up any existing terraform.tfstate
- [ ] Notified team of deployment
- [ ] Prepared rollback plan

---

## Support & Documentation

- **Terraform Docs**: https://registry.terraform.io/
- **AWS Provider Docs**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **Jenkins Docs**: https://www.jenkins.io/doc/
- **Pipeline Syntax**: https://www.jenkins.io/doc/book/pipeline/syntax/

---

## Example: Running Your First Pipeline

```bash
# 1. Push code to GitHub
git add .
git commit -m "Add Jenkins pipeline for dev deployment"
git push origin main

# 2. Trigger Jenkins job
# Option A: Manual
#   Jenkins Dashboard → terraform-dev-provisioning → Build with Parameters
#   ACTION: PLAN
#   Click Build

# Option B: Webhook
#   Jenkins will trigger automatically on push

# 3. Monitor build
# Jenkins Dashboard → terraform-dev-provisioning → [Build #1]
# Watch console output in real-time

# 4. Review plan output
# Jenkins will display terraform plan
# Check what resources will be created

# 5. Approve and apply
# Click "APPROVE & APPLY" when prompted
# Jenkins will apply the configuration

# 6. Access infrastructure
# Jenkins output shows:
#   - VPC ID
#   - EC2 Public IPs
#   - Security Group IDs
# SSH to instance: ssh -i key.pem ubuntu@<public-ip>
```

---

## Next Steps

1. Set up Jenkins instance (or use managed Jenkins)
2. Configure credentials in Jenkins
3. Create pipeline job
4. Test with PLAN action first
5. Review outputs
6. Run with APPLY action
7. Verify infrastructure in AWS Console
8. Test web server access
9. Set up monitoring and logging
10. Document runbooks for ops team
