# AWS Secrets Manager Configuration Guide

## Overview

AWS Secrets Manager stores sensitive data that your Terraform infrastructure needs. This guide shows **exactly** what keys/values you need to configure.

---

## Current Setup: What's Being Used

### Architecture Flow

```
┌────────────────────────────────────────────────────────┐
│  Your Code (terraform.tfvars, main.tf)                 │
│  - NOT storing passwords here (safe for Git)           │
│  - Only references: secrets_manager_secret_name         │
└────────────────────────────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────┐
│  AWS Secrets Manager (Secret Name: dev/terraform-env-vars)   │
│  - Encrypted vault                                     │
│  - Contains: Keys & Values (JSON)                      │
│  - Only authorized services read this                  │
└────────────────────────────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────┐
│  Terraform Module: modules/secrets/secret_manager/     │
│  - Reads from Secrets Manager                          │
│  - Makes secrets available to other resources          │
└────────────────────────────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────┐
│  EC2 Instance (Apache2 Web Server)                     │
│  - Can access secrets if IAM role permits              │
│  - Uses values at runtime                              │
└────────────────────────────────────────────────────────┘
```

---

## Secret Reference in Your Code

### From: env/dev/terraform.tfvars

```hcl
# Secrets Manager Configuration
secrets_manager_secret_name = "dev/terraform-env-vars"

# ↑ This is the secret name you need to create
# ↓ The secret contains key/value pairs
```

### From: env/dev/main.tf

```hcl
# Data source to fetch secrets from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "env_secrets" {
  secret_id = var.secrets_manager_secret_name  # "dev/terraform-env-vars"
}

locals {
  secrets = jsondecode(data.aws_secretsmanager_secret_version.env_secrets.secret_string)
}
```

**What this does:**
- Reads the secret `dev/terraform-env-vars` from AWS
- Decodes it as JSON
- Stores it in `local.secrets` variable
- Available throughout Terraform as: `local.secrets.KEY_NAME`

---

## Required Secret Keys & Values

### Current Setup: Minimal Configuration

Since your infrastructure is **basic** (just EC2 + Apache2), the minimal secret you need is:

```json
{
  "environment": "development",
  "app_version": "1.0.0",
  "deployment_date": "2026-01-15"
}
```

**Why these?**
- `environment`: Identifies which environment is running (dev/stage/prod)
- `app_version`: Tracks which version of app is deployed
- `deployment_date`: When infrastructure was deployed

---

## Extended Configuration: Ready for Growth

If you plan to add databases, APIs, or authentication, use this comprehensive structure:

```json
{
  "environment": "development",
  "app_version": "1.0.0",
  "deployment_date": "2026-01-15",
  
  "database_config": {
    "host": "db.example.com",
    "port": "5432",
    "username": "db_admin",
    "password": "your-secure-db-password",
    "database": "app_db"
  },
  
  "api_config": {
    "api_key": "sk-abcd1234efgh5678",
    "api_secret": "secret-api-key-value",
    "api_endpoint": "https://api.example.com"
  },
  
  "authentication": {
    "jwt_secret": "your-jwt-signing-secret",
    "session_timeout": "3600",
    "oauth_client_id": "your-oauth-id",
    "oauth_client_secret": "your-oauth-secret"
  },
  
  "application": {
    "app_name": "my-terraform-app",
    "log_level": "info",
    "debug_mode": "false",
    "max_connections": "100"
  }
}
```

---

## Step-by-Step: Create the Secret

### Option 1: Using AWS CLI (Recommended)

#### Create Minimal Secret

```bash
aws secretsmanager create-secret \
  --name dev/terraform-env-vars \
  --region us-east-1 \
  --secret-string '{
    "environment": "development",
    "app_version": "1.0.0",
    "deployment_date": "2026-01-15"
  }'
```

**Expected Output:**
```json
{
    "ARN": "arn:aws:secretsmanager:us-east-1:123456789012:secret:dev/terraform-env-vars-XXXXX",
    "Name": "dev/terraform-env-vars",
    "VersionId": "12345678-1234-1234-1234-123456789012"
}
```

#### Create Extended Secret

```bash
aws secretsmanager create-secret \
  --name dev/terraform-env-vars \
  --region us-east-1 \
  --secret-string '{
    "environment": "development",
    "app_version": "1.0.0",
    "deployment_date": "2026-01-15",
    "database_config": {
      "host": "my-db.example.com",
      "port": "5432",
      "username": "db_admin",
      "password": "MySecurePassword123!",
      "database": "my_app_db"
    },
    "api_config": {
      "api_key": "sk-1234567890abcdef",
      "api_secret": "secret-key-value",
      "api_endpoint": "https://api.example.com"
    },
    "authentication": {
      "jwt_secret": "jwt-signing-key-12345",
      "session_timeout": "3600",
      "oauth_client_id": "oauth-id-12345",
      "oauth_client_secret": "oauth-secret-value"
    },
    "application": {
      "app_name": "my-terraform-app",
      "log_level": "info",
      "debug_mode": "false",
      "max_connections": "100"
    }
  }'
```

### Option 2: Using AWS Console (GUI)

```
1. Login to AWS Console
2. Search: "Secrets Manager"
3. Click: "Store a new secret"
4. Secret type: "Other type of secret"
5. Key/value section:
   - Enter keys from above
   - Enter corresponding values
6. Secret name: dev/terraform-env-vars
7. Click: "Store secret"
```

---

## Verify Secret Was Created

### Check Secret Exists

```bash
aws secretsmanager describe-secret \
  --secret-id dev/terraform-env-vars \
  --region us-east-1

# Output:
# {
#     "ARN": "arn:aws:secretsmanager:us-east-1:...",
#     "Name": "dev/terraform-env-vars",
#     "Status": "Available",
#     "CreatedDate": 1234567890.0,
#     "LastChangedDate": 1234567890.0
# }
```

### View Secret Content

```bash
# ⚠️ WARNING: This shows the actual secret values!
# Only run on secure machines

aws secretsmanager get-secret-value \
  --secret-id dev/terraform-env-vars \
  --region us-east-1

# Output:
# {
#     "ARN": "arn:aws:secretsmanager:us-east-1:...",
#     "Name": "dev/terraform-env-vars",
#     "VersionId": "12345678-...",
#     "SecretString": "{\"environment\":\"development\",...}",
#     "VersionStages": ["AWSCURRENT"],
#     "CreatedDate": 1234567890.0
# }
```

---

## How Terraform Reads the Secret

### In Your Code (env/dev/main.tf)

```hcl
# Step 1: Fetch the secret
data "aws_secretsmanager_secret_version" "env_secrets" {
  secret_id = "dev/terraform-env-vars"
}

# Step 2: Parse JSON
locals {
  secrets = jsondecode(data.aws_secretsmanager_secret_version.env_secrets.secret_string)
}

# Step 3: Access individual keys
# local.secrets.environment           → "development"
# local.secrets.app_version           → "1.0.0"
# local.secrets.deployment_date       → "2026-01-15"
# local.secrets.database_config.host  → "my-db.example.com"
```

### Using Secrets in EC2 Instance

**In scripts/install_apache2.sh or other user_data:**

```bash
#!/bin/bash
# Get secrets from AWS Secrets Manager
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id dev/terraform-env-vars \
  --region us-east-1 \
  --query SecretString \
  --output text)

# Extract individual values
ENVIRONMENT=$(echo $SECRET | jq -r '.environment')
APP_VERSION=$(echo $SECRET | jq -r '.app_version')
DB_HOST=$(echo $SECRET | jq -r '.database_config.host')
DB_USER=$(echo $SECRET | jq -r '.database_config.username')
DB_PASS=$(echo $SECRET | jq -r '.database_config.password')

# Use in your application
echo "Deploying $APP_VERSION to $ENVIRONMENT"
echo "Connecting to database: $DB_USER@$DB_HOST"

# Export as environment variables for your app
export DATABASE_URL="postgresql://$DB_USER:$DB_PASS@$DB_HOST/my_app_db"
```

---

## Secret Naming Convention

### For Your Setup

**Secret Names in AWS:**

```
dev/terraform-env-vars       ← Dev environment secrets
stage/terraform-env-vars     ← Stage environment secrets
prod/terraform-env-vars      ← Prod environment secrets (future)
```

**Referenced in Code:**

```hcl
# env/dev/terraform.tfvars
secrets_manager_secret_name = "dev/terraform-env-vars"

# env/stage/terraform.tfvars
secrets_manager_secret_name = "stage/terraform-env-vars"
```

---

## Common Secret Keys Reference

### Metadata Keys (Always Include)

```json
{
  "environment": "dev",           // dev, stage, prod
  "app_version": "1.0.0",         // Version number
  "deployment_date": "2026-01-15" // When deployed
}
```

### Database Keys (If using database)

```json
{
  "database_config": {
    "host": "db.example.com",
    "port": "5432",
    "username": "admin",
    "password": "secure-password",
    "database": "app_db"
  }
}
```

### API Keys (If using external APIs)

```json
{
  "api_config": {
    "api_key": "sk-xxxxx",
    "api_secret": "secret-key",
    "api_endpoint": "https://api.example.com"
  }
}
```

### Authentication Keys (If using auth)

```json
{
  "authentication": {
    "jwt_secret": "jwt-key",
    "session_timeout": "3600",
    "oauth_client_id": "id-xxx",
    "oauth_client_secret": "secret-xxx"
  }
}
```

### Application Configuration

```json
{
  "application": {
    "app_name": "my-app",
    "log_level": "info",
    "debug_mode": "false",
    "max_connections": "100"
  }
}
```

---

## Update Existing Secret

### Add/Change Values

```bash
# Update with new values (preserves existing keys)
aws secretsmanager update-secret \
  --secret-id dev/terraform-env-vars \
  --secret-string '{
    "environment": "development",
    "app_version": "1.0.1",
    "deployment_date": "2026-01-16",
    "new_key": "new_value"
  }'

# Output:
# {
#     "ARN": "arn:aws:secretsmanager:us-east-1:...",
#     "Name": "dev/terraform-env-vars",
#     "VersionId": "new-version-id"
# }
```

### View Secret History

```bash
aws secretsmanager list-secret-version-ids \
  --secret-id dev/terraform-env-vars \
  --region us-east-1
```

---

## Security Best Practices

### ✅ DO's

```
✓ Store passwords in Secrets Manager
✓ Store API keys in Secrets Manager
✓ Use IAM roles (not hardcoded credentials)
✓ Enable encryption (default: AWS KMS)
✓ Restrict who can access secrets (IAM policies)
✓ Rotate secrets regularly
✓ Enable CloudTrail for audit logs
✓ Use descriptive secret names
```

### ❌ DON'Ts

```
✗ Don't store secrets in terraform.tfvars
✗ Don't commit secrets to Git
✗ Don't hardcode passwords in code
✗ Don't share AWS credentials
✗ Don't use same secret for multiple environments
✗ Don't grant Everyone access to secrets
✗ Don't log secret values
✗ Don't use weak passwords
```

---

## IAM Permissions Required

### For Terraform to Read Secrets

The IAM user running Terraform needs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecrets"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:ACCOUNT-ID:secret:dev/*"
    }
  ]
}
```

### For EC2 Instance to Read Secrets

Attach this policy to EC2 IAM role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:ACCOUNT-ID:secret:dev/*"
    }
  ]
}
```

---

## Complete Example: Full Setup

### Step 1: Create the Secret

```bash
aws secretsmanager create-secret \
  --name dev/terraform-env-vars \
  --region us-east-1 \
  --description "Development environment secrets for Terraform" \
  --secret-string '{
    "environment": "development",
    "app_version": "1.0.0",
    "deployment_date": "2026-01-15",
    "database_config": {
      "host": "postgres.example.com",
      "port": "5432",
      "username": "terraform_user",
      "password": "TerraformSecure123!@#",
      "database": "terraform_db"
    },
    "api_config": {
      "api_key": "sk-terraform-123456789",
      "api_secret": "secret-key-for-api",
      "api_endpoint": "https://api.example.com"
    },
    "application": {
      "app_name": "terraform-infra-app",
      "log_level": "info",
      "debug_mode": "false",
      "max_connections": "50"
    }
  }'
```

### Step 2: Verify Creation

```bash
aws secretsmanager describe-secret \
  --secret-id dev/terraform-env-vars \
  --region us-east-1
```

### Step 3: Terraform Uses It

**env/dev/terraform.tfvars:**
```hcl
secrets_manager_secret_name = "dev/terraform-env-vars"
```

**env/dev/main.tf:**
```hcl
data "aws_secretsmanager_secret_version" "env_secrets" {
  secret_id = var.secrets_manager_secret_name
}

locals {
  secrets = jsondecode(data.aws_secretsmanager_secret_version.env_secrets.secret_string)
}

# Use in resources:
# local.secrets.database_config.host
# local.secrets.api_config.api_key
# etc.
```

### Step 4: Terraform Plan

```bash
cd env/dev
terraform init
terraform plan

# Should show secrets being used without exposing values
# ✓ No passwords in plan output!
```

### Step 5: EC2 Instance Accesses Secrets

**scripts/install_apache2.sh:**
```bash
#!/bin/bash
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id dev/terraform-env-vars \
  --region us-east-1 \
  --query SecretString \
  --output text)

APP_VERSION=$(echo $SECRET | jq -r '.app_version')
echo "Deploying version: $APP_VERSION"
```

---

## Summary: What You Need

| Item | Example | Required? |
|------|---------|-----------|
| Secret Name | `dev/terraform-env-vars` | ✅ Yes |
| Environment Key | `"environment": "development"` | ✅ Yes |
| App Version Key | `"app_version": "1.0.0"` | ✅ Yes |
| Deployment Date | `"deployment_date": "2026-01-15"` | ✅ Yes |
| Database Config | `"database_config": {...}` | ❓ If using DB |
| API Keys | `"api_config": {...}` | ❓ If using APIs |
| Auth Config | `"authentication": {...}` | ❓ If using auth |
| App Config | `"application": {...}` | ❓ Optional |

---

## Quick Command Reference

```bash
# Create secret (minimal)
aws secretsmanager create-secret \
  --name dev/terraform-env-vars \
  --region us-east-1 \
  --secret-string '{"environment":"dev","app_version":"1.0.0","deployment_date":"2026-01-15"}'

# View secret
aws secretsmanager get-secret-value \
  --secret-id dev/terraform-env-vars \
  --region us-east-1

# Update secret
aws secretsmanager update-secret \
  --secret-id dev/terraform-env-vars \
  --secret-string '{...}'

# Delete secret (with recovery window)
aws secretsmanager delete-secret \
  --secret-id dev/terraform-env-vars \
  --recovery-window-in-days 7

# List all secrets
aws secretsmanager list-secrets --region us-east-1
```

---

## Next Steps

1. **Create the secret** using the commands above
2. **Add required keys** based on your needs
3. **Test Terraform** reads it successfully
4. **Add IAM permissions** for EC2 to read it
5. **Deploy infrastructure** knowing secrets are secure!

