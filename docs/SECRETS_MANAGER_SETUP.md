# AWS Secrets Manager Setup Guide

## Overview

This guide explains how to create and structure secrets in AWS Secrets Manager for use with this Terraform infrastructure.

**Why Secrets Manager?**
- Centralized secret management
- Automatic rotation support
- Audit logging via CloudTrail
- Fine-grained IAM access control
- No secrets in Git or code

---

## 1️⃣ CREATE SECRETS FOR EACH ENVIRONMENT

### Prerequisites
- AWS CLI installed and configured
- IAM permissions: `secretsmanager:CreateSecret`
- For each environment (dev, stage, prod)

### Step 1: Create Development Secret

```bash
aws secretsmanager create-secret \
  --name dev/app-config \
  --region ap-south-1 \
  --secret-string '{
    "app_name": "dev-web-app",
    "app_version": "0.1.0",
    "contact_email": "dev-team@company.com"
  }'
```

**Output:**
```json
{
    "ARN": "arn:aws:secretsmanager:ap-south-1:ACCOUNT_ID:secret:dev/app-config-ABC123",
    "Name": "dev/app-config",
    "VersionId": "xxxxx"
}
```

### Step 2: Create Staging Secret

```bash
aws secretsmanager create-secret \
  --name stage/app-config \
  --region ap-south-1 \
  --secret-string '{
    "app_name": "stage-web-app",
    "app_version": "1.0.0-rc1",
    "contact_email": "stage-team@company.com"
  }'
```

### Step 3: Create Production Secret

```bash
aws secretsmanager create-secret \
  --name prod/app-config \
  --region ap-south-1 \
  --secret-string '{
    "app_name": "prod-web-app",
    "app_version": "1.0.0",
    "contact_email": "ops@company.com"
  }'
```

---

## 2️⃣ SECRET STRUCTURE

Each secret must be a valid JSON object with the following fields:

```json
{
  "app_name": "string - application name (used in EC2 tags)",
  "app_version": "string - semantic version (used in EC2 tags)",
  "contact_email": "string - team/ops email (used in EC2 tags)"
}
```

### Why These Fields?

- **app_name**: Used to tag EC2 instances so you know which app is running
- **app_version**: Used for deployment tracking and compliance audits
- **contact_email**: Used for incident response and owner identification

### Optional Extension

You can add more fields if needed:

```json
{
  "app_name": "prod-web-app",
  "app_version": "1.0.0",
  "contact_email": "ops@company.com",
  "slack_webhook": "https://hooks.slack.com/services/...",
  "pagerduty_key": "xxx-yyy-zzz",
  "backup_frequency": "daily"
}
```

The Terraform code uses `lookup(local.secrets, "field_name", "default_value")` to safely extract fields with defaults.

---

## 3️⃣ TERRAFORM INTEGRATION

### How Terraform Consumes Secrets

In `env/dev/main.tf` (and stage/prod):

```hcl
# Fetch secret from Secrets Manager
data "aws_secretsmanager_secret_version" "env_secrets" {
  secret_id = var.secrets_manager_secret_name
}

# Decode JSON and extract values
locals {
  secrets = jsondecode(data.aws_secretsmanager_secret_version.env_secrets.secret_string)
  
  # Use lookup() to safely extract with defaults
  app_name        = lookup(local.secrets, "app_name", "${var.environment}-app")
  app_version     = lookup(local.secrets, "app_version", "1.0.0")
  contact_email   = lookup(local.secrets, "contact_email", "ops@company.com")
}
```

### How Secrets Are Applied to EC2

In EC2 module tags:

```hcl
tags = {
  Environment    = var.environment
  Name           = "${var.environment}-web-server"
  AppName        = local.app_name
  AppVersion     = local.app_version
  ManagedBy      = "Terraform"
  ContactEmail   = local.contact_email
}
```

**Result:** EC2 instances are automatically tagged with app metadata from Secrets Manager.

---

## 4️⃣ VERIFY SECRETS ARE CORRECTLY SET

### List All Secrets

```bash
aws secretsmanager list-secrets --region ap-south-1 --filters Key=name,Values=dev
```

### Retrieve Secret Value

```bash
aws secretsmanager get-secret-value \
  --secret-id dev/app-config \
  --region ap-south-1 \
  --query SecretString \
  --output text
```

**Output:**
```json
{
  "app_name": "dev-web-app",
  "app_version": "0.1.0",
  "contact_email": "dev-team@company.com"
}
```

### Decode and Pretty-Print

```bash
aws secretsmanager get-secret-value \
  --secret-id dev/app-config \
  --region ap-south-1 \
  --query SecretString \
  --output text | jq .
```

---

## 5️⃣ UPDATE TERRAFORM VARIABLES

Ensure `terraform.tfvars` points to the correct secret name:

**env/dev/terraform.tfvars:**
```hcl
secrets_manager_secret_name = "dev/app-config"
```

**env/stage/terraform.tfvars:**
```hcl
secrets_manager_secret_name = "stage/app-config"
```

**env/prod/terraform.tfvars:**
```hcl
secrets_manager_secret_name = "prod/app-config"
```

---

## 6️⃣ IAM PERMISSIONS REQUIRED

### Jenkins/Terraform Execution Role

The IAM role running Terraform must have:

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
      "Resource": [
        "arn:aws:secretsmanager:ap-south-1:ACCOUNT_ID:secret:dev/*",
        "arn:aws:secretsmanager:ap-south-1:ACCOUNT_ID:secret:stage/*",
        "arn:aws:secretsmanager:ap-south-1:ACCOUNT_ID:secret:prod/*"
      ]
    }
  ]
}
```

### EC2 Instance Role

The IAM role attached to EC2 instances must have:

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
      "Resource": "arn:aws:secretsmanager:ap-south-1:ACCOUNT_ID:secret:*"
    }
  ]
}
```

See `modules/iam/instance_role/main.tf` for the complete role definition.

---

## 7️⃣ TESTING TERRAFORM PLAN

Once secrets are created, test the Terraform plan:

```bash
cd env/dev

# Initialize Terraform
terraform init \
  -backend-config="bucket=terraform-state-dev" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="dynamodb_table=terraform-locks" \
  -backend-config="encrypt=true"

# Plan the deployment
terraform plan -out=tfplan

# Check that secrets are being fetched (look for no errors)
```

**Expected output:**
```
Acquiring state lock. This may take a few moments...
data.aws_secretsmanager_secret_version.env_secrets: Reading...
data.aws_secretsmanager_secret_version.env_secrets: Read complete after 0s
...
```

If you see an error like:
```
Error: InvalidRequestException: The parameter SecretId can't be empty
```

It means `secrets_manager_secret_name` is not set in `terraform.tfvars`.

---

## 8️⃣ ROTATING SECRETS

### Update an Existing Secret

```bash
aws secretsmanager update-secret \
  --secret-id dev/app-config \
  --secret-string '{
    "app_name": "dev-web-app-v2",
    "app_version": "0.2.0",
    "contact_email": "dev-team@company.com"
  }' \
  --region ap-south-1
```

### Re-apply Terraform to Pick Up Changes

```bash
terraform apply -refresh-only

# Then plan/apply normally
terraform plan -out=tfplan
terraform apply tfplan
```

This will update EC2 tags with new secret values.

---

## 9️⃣ TROUBLESHOOTING

### Secret Not Found

**Error:**
```
InvalidRequestException: Secrets Manager can't find the specified secret
```

**Solution:**
- Verify secret exists: `aws secretsmanager list-secrets --region ap-south-1`
- Verify region matches (ap-south-1 in this setup)
- Verify `secrets_manager_secret_name` variable is correct

### Permission Denied

**Error:**
```
AccessDeniedException: User: arn:aws:iam::ACCOUNT_ID:user/terraform is not authorized
```

**Solution:**
- Check IAM role/user has `secretsmanager:GetSecretValue` permission
- Check resource ARN matches secret name (wildcards ok for pattern matching)
- Verify the principal can `sts:AssumeRole` if using a role

### Invalid JSON in Secret

**Error:**
```
Error: Invalid JSON in secret value
```

**Solution:**
- Validate JSON: `echo '{"key": "value"}' | jq .`
- Use AWS Console to view and fix the secret value
- Re-apply Terraform after fixing

---

## 🔟 SECURITY BEST PRACTICES

1. ✅ Never commit secrets to Git (use terraform.tfvars in .gitignore)
2. ✅ Use IAM roles, not access keys
3. ✅ Restrict secret access by resource ARN
4. ✅ Enable CloudTrail logging for audit
5. ✅ Rotate secrets regularly (annually minimum)
6. ✅ Use separate secrets per environment (dev/stage/prod)
7. ✅ Never hardcode secret values in code
8. ✅ Use KMS encryption for secrets at rest

---

## SUMMARY

| Step | Command | Purpose |
|------|---------|---------|
| Create Secret | `aws secretsmanager create-secret` | Store environment-specific config |
| Retrieve Secret | `aws secretsmanager get-secret-value` | Verify secret contents |
| Update Secret | `aws secretsmanager update-secret` | Rotate or change values |
| Terraform Plan | `terraform plan` | Verify secrets fetch correctly |
| Terraform Apply | `terraform apply` | Deploy with secret values in tags |

Once all three secrets are created (dev, stage, prod), you're ready to deploy!

