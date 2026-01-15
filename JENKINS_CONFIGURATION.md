# Jenkins Pipeline - Configuration Guide

## No Hardcoding Approach

All configuration values are externalized to `jenkins.env` file. This ensures:
- ✅ No hardcoded values in Jenkinsfile
- ✅ Easy environment switching (dev/stage/prod)
- ✅ Safe for git commits (no credentials)
- ✅ Single source of truth

---

## Configuration Files

### 1. jenkins.env (Primary Configuration)

**Location:** `/home/shazil/Desktop/Terraform-project/jenkins.env`

Contains all configurable parameters:

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

**How to Use:**
1. Clone repository
2. Edit `jenkins.env` with your values
3. Commit to git (safe, no secrets)
4. Jenkins automatically loads values from Jenkinsfile

### 2. Jenkinsfile (Pipeline Definition)

**Location:** `/home/shazil/Desktop/Terraform-project/Jenkinsfile`

Key features:
- All hardcoded values removed
- Uses `${env.VARIABLE}` for dynamic values
- Environment-aware (dev/stage selection)
- No credentials hardcoded

### 3. scripts/load_jenkins_config.sh (Validation Script)

**Location:** `/home/shazil/Desktop/Terraform-project/scripts/load_jenkins_config.sh`

- Validates jenkins.env file
- Checks all required values are set
- Useful for pre-deployment validation

---

## Jenkins Parameters (User Input)

When building the pipeline, users can select:

### 1. ENVIRONMENT
- Choose: `dev` or `stage`
- Determines which `env/*/main.tf` to use
- Sets terraform working directory dynamically

### 2. ACTION
- Choose: `PLAN`, `APPLY`, or `DESTROY`
- PLAN: Preview changes only
- APPLY: Deploy infrastructure
- DESTROY: Delete all resources

### 3. AUTO_APPROVE
- Default: `false`
- When `true`: Skips manual approval (not recommended)
- When `false`: Requires human approval via Jenkins

### 4. AWS_REGION
- Default: `us-east-1`
- Can override per build

### 5. TERRAFORM_VERSION
- Default: `1.5.0`
- Can use different versions if needed

---

## Jenkins Job Configuration (One-time Setup)

### Step 1: Create Jenkins Job

```
Jenkins Dashboard
  → New Item
  → Job name: "terraform-provisioning"
  → Type: Pipeline
  → Click OK
```

### Step 2: Configure Credentials

In Jenkins Dashboard → Manage Credentials → Global:

1. **AWS Credentials**
   - ID: `aws-credentials`
   - Type: AWS Credentials
   - Access Key: (your AWS access key)
   - Secret Key: (your AWS secret key)

2. **Secrets Manager Secret**
   - ID: `secrets-manager-secret-id`
   - Type: Secret text
   - Secret: `dev/terraform-env-vars` (or your secret name)

3. **GitHub Token** (if private repo)
   - ID: `github-credentials`
   - Type: Username with password
   - Username: (GitHub username)
   - Password: (GitHub personal access token)

### Step 3: Pipeline Configuration

In job configuration page → Pipeline tab:

**Definition:** Pipeline script from SCM

**SCM:** Git
- Repository URL: `${GIT_REPO_URL}` (reads from jenkins.env)
- Credentials: `github-credentials`
- Branch: `${GIT_BRANCH}` (reads from jenkins.env)
- Script Path: `Jenkinsfile`

### Step 4: Update jenkins.env

Edit the `jenkins.env` file in repository:

```bash
GIT_REPO_URL=https://github.com/your-org/terraform-project.git
GIT_BRANCH=*/main
JENKINS_APPROVERS=terraform-approvers
JENKINS_NOTIFY_EMAIL=devops-team@example.com
AWS_REGION=us-east-1
TERRAFORM_VERSION=1.5.0
```

---

## How It Works

### 1. User Triggers Build
```
Jenkins Dashboard → terraform-provisioning → Build with Parameters
- ENVIRONMENT: dev
- ACTION: PLAN
- AWS_REGION: us-east-1
```

### 2. Pipeline Executes
```groovy
// Jenkinsfile reads from jenkins.env
environment {
    TF_WORKING_DIR = "env/${params.ENVIRONMENT}"     // env/dev
    AWS_REGION = "${params.AWS_REGION}"              // us-east-1
    ENVIRONMENT = "${params.ENVIRONMENT}"            // dev
}
```

### 3. Environment Variables
```
TF_WORKING_DIR = env/dev
AWS_REGION = us-east-1
ENVIRONMENT = dev
BUILD_TIMESTAMP = 20260115_143022
```

### 4. Stages Execute
- Checkout code
- Validate Terraform
- Run plan for dev environment
- Display outputs
- Wait for approval (if APPLY)
- Execute terraform apply/destroy

---

## Example Usage

### Scenario 1: Plan Dev Deployment
```
1. Jenkins: Build with Parameters
   - ENVIRONMENT: dev
   - ACTION: PLAN
   - AUTO_APPROVE: false

2. Pipeline executes:
   - Checks out code
   - Runs: terraform plan (for env/dev)
   - Shows plan output
   - Jenkins archive artifacts

3. Review plan in Jenkins artifacts
4. No resources created (PLAN only)
```

### Scenario 2: Apply Dev Deployment
```
1. Jenkins: Build with Parameters
   - ENVIRONMENT: dev
   - ACTION: APPLY
   - AUTO_APPROVE: false

2. Pipeline executes:
   - Checks out code
   - Runs: terraform plan (for env/dev)
   - Shows plan output

3. Manual approval step:
   - Jenkins requires human approval
   - Click "APPROVE & APPLY"
   - 30-minute timeout

4. Pipeline continues:
   - Runs: terraform apply
   - Creates EC2, VPC, Security Groups
   - Outputs instance IPs
   - Sends email notification

5. Access infrastructure:
   - SSH to EC2: ssh -i key.pem ubuntu@<ip>
   - Visit Apache: http://<ip>
```

### Scenario 3: Deploy to Stage
```
1. Jenkins: Build with Parameters
   - ENVIRONMENT: stage
   - ACTION: APPLY
   - AWS_REGION: us-east-1

2. Pipeline uses:
   - TF_WORKING_DIR = env/stage
   - Reads stage terraform.tfvars
   - Creates 2x t2.small instances
   - Creates multiple subnets
```

---

## File Structure

```
Terraform-project/
├── Jenkinsfile                    # Pipeline definition (no hardcoding)
├── jenkins.env                    # Configuration values (update here!)
├── env/
│   ├── dev/
│   │   ├── main.tf               # References modules dynamically
│   │   ├── terraform.tfvars      # Dev-specific values
│   │   └── ...
│   └── stage/
│       └── ...
├── modules/
│   └── (reusable modules)
└── scripts/
    ├── load_jenkins_config.sh     # Loads jenkins.env
    ├── validate_deployment.sh     # Pre-deployment checks
    └── install_apache2.sh         # EC2 user_data
```

---

## Environment-Specific Behavior

### Dev Environment
**jenkins.env + env/dev/terraform.tfvars:**
```hcl
aws_region = "us-east-1"
vpc_cidr = "10.0.0.0/16"
instance_type = "t2.micro"
instance_count = 1
```

### Stage Environment
**jenkins.env + env/stage/terraform.tfvars:**
```hcl
aws_region = "us-east-1"
vpc_cidr = "10.1.0.0/16"
instance_type = "t2.small"
instance_count = 2
```

Jenkins parameter `ENVIRONMENT` switches which env directory is used!

---

## Security

### ✅ What's Safe (Committed to Git)
- `Jenkinsfile` - No secrets, no hardcoding
- `jenkins.env` - Configuration only, no credentials
- `env/*/terraform.tfvars` - Environment values, no secrets
- `.gitignore` - Excludes state files and sensitive data

### 🔒 What's NOT Safe (Stored in Jenkins Secrets)
- AWS Access Keys - Jenkins Credentials
- AWS Secret Keys - Jenkins Credentials
- GitHub Token - Jenkins Credentials
- Database Passwords - AWS Secrets Manager

### ✔️ Flow
```
jenkins.env (config)
      ↓
Jenkinsfile (reads config)
      ↓
Jenkins Credentials (credentials)
      ↓
Terraform (uses both)
      ↓
AWS (applies configuration)
```

---

## Troubleshooting

### Issue: "Cannot find GIT_REPO_URL"
**Solution:** Update `jenkins.env` with your repository URL
```bash
GIT_REPO_URL=https://github.com/your-org/terraform-project.git
```

### Issue: "Build parameter ENVIRONMENT is empty"
**Solution:** Check job configuration → Parameters
- Ensure parameter name matches: `ENVIRONMENT`
- Choices should be: `dev,stage`

### Issue: "Approval step hangs forever"
**Solution:** Check Jenkins configuration
- System Configuration → Email Notification
- Verify SMTP server
- Check user email configuration

### Issue: "AWS credentials not found"
**Solution:** Create credentials in Jenkins
- Manage Credentials → Global → Add AWS Credentials
- ID must match: `aws-credentials`

---

## Best Practices

1. **Use jenkins.env for all configuration**
   - Easy to change without editing Jenkinsfile
   - Commit to git safely
   - Version controlled

2. **Use Parameters for build-time decisions**
   - ENVIRONMENT: dev/stage selection
   - ACTION: plan/apply/destroy
   - AUTO_APPROVE: skip approval only when safe

3. **Require approval before apply/destroy**
   - Set AUTO_APPROVE=false
   - Restrict approvers to experienced team members
   - Review terraform plan output

4. **Use separate environments**
   - dev for testing
   - stage for pre-production
   - prod for production (separate pipeline)

5. **Monitor notifications**
   - Enable email notifications
   - Share with team
   - Create audit trail

---

## Next Steps

1. ✅ Edit `jenkins.env` with your values
2. ✅ Create Jenkins credentials
3. ✅ Create Jenkins pipeline job
4. ✅ Test with PLAN action
5. ✅ Review outputs
6. ✅ Run with APPLY action
7. ✅ Verify infrastructure
8. ✅ Access web server
9. ✅ Set up monitoring
10. ✅ Document runbooks
