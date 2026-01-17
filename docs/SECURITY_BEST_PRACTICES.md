# Security Best Practices Guide

This document outlines security best practices for the Terraform + Jenkins CI/CD pipeline.

## Critical Security Principles

### 1. Never Store Secrets in Git

**CRITICAL:** AWS credentials, API keys, and sensitive values must NEVER be committed to Git.

```bash
# Verify nothing sensitive was committed
git log --all -S "AKIA" --oneline  # Search for AWS key patterns
git log --all -S "secret" --oneline # Search for "secret" keyword

# If found, use git-filter-branch or BFG Repo Cleaner to remove
```

**Protected by .gitignore:**
- `*.tfvars` - Terraform variable files
- `.env*` - Environment files
- `~/.aws/` - AWS credential files
- `.terraform/` - Terraform modules and state

### 2. No AWS Credentials in Jenkins

**CRITICAL:** Never hardcode AWS credentials in Jenkinsfile or Jenkins configuration.

❌ **WRONG:**
```groovy
environment {
    AWS_ACCESS_KEY_ID = "AKIA..."
    AWS_SECRET_ACCESS_KEY = "..."
}
```

✓ **CORRECT:**
```groovy
// Use IAM role (EC2) or ~/.aws/credentials (bare metal)
// No hardcoded credentials!
```

### 3. IAM Least Privilege Policy

Each IAM user/role should have **minimum required permissions only**.

#### Example: Jenkins Minimal Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-*",
        "arn:aws:s3:::terraform-state-*/*"
      ]
    },
    {
      "Sid": "DynamoDBStateLocking",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-locks"
    }
  ]
}
```

### 4. Secrets Manager for All Sensitive Data

All environment-specific secrets should be stored in AWS Secrets Manager, not in code.

#### Secure Pattern:

```hcl
# Terraform fetches secret from Secrets Manager
data "aws_secretsmanager_secret_version" "env_secrets" {
  secret_id = "dev/terraform-env-vars"
}

locals {
  secrets = jsondecode(data.aws_secretsmanager_secret_version.env_secrets.secret_string)
}

# Use the secrets
module "vpc" {
  vpc_cidr = local.secrets.vpc_cidr
}
```

#### What Goes in Secrets Manager:

- Database passwords
- API keys
- SSH key passphrases
- Certificate passwords
- Private encryption keys

#### What Should NOT:

- Public IPs
- DNS names
- VPC CIDR ranges
- Instance types
- Public configuration

### 5. S3 State Bucket Security

Protect your Terraform state bucket (contains sensitive values):

```bash
# Block all public access
aws s3api put-public-access-block \
  --bucket terraform-state-dev \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Enable versioning (recover deleted states)
aws s3api put-bucket-versioning \
  --bucket terraform-state-dev \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket terraform-state-dev \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}
    }]
  }'

# Enable access logging
aws s3api put-bucket-logging \
  --bucket terraform-state-dev \
  --bucket-logging-status '{
    "LoggingEnabled": {
      "TargetBucket": "terraform-state-logs",
      "TargetPrefix": "dev/"
    }
  }'
```

### 6. Environment Isolation

Maintain strict separation between dev, stage, and prod:

| Aspect | Dev | Stage | Prod |
|--------|-----|-------|------|
| **AWS Account** | Same | Same | Same (ideally separate) |
| **Terraform State** | Separate S3 key | Separate S3 key | Separate S3 key |
| **VPC CIDR** | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| **Instance Type** | t3.micro | t3.small | t3.medium+ |
| **Apply Approval** | None | Manual | Mandatory |
| **IAM Permissions** | Full | Limited | Restricted |

### 7. Approval Process for Prod

Implement multi-level approval for production deployments:

```groovy
stage('Approve Prod Deployment') {
    when {
        expression { params.ENVIRONMENT == 'prod' && params.ACTION == 'APPLY' }
    }
    steps {
        script {
            // Require approval from specific users
            def approvers = ['devops-lead', 'platform-engineer']
            timeout(time: 1, unit: 'HOURS') {
                input(
                    message: 'Deploy to PRODUCTION?',
                    ok: 'Deploy to Prod',
                    submitter: approvers.join(',')
                )
            }
        }
    }
}
```

### 8. Audit and Logging

Enable comprehensive logging for all infrastructure changes:

```bash
# Enable CloudTrail for AWS API logging
aws cloudtrail create-trail \
  --name terraform-audit-trail \
  --s3-bucket-name terraform-audit-logs \
  --include-global-service-events

# Enable S3 access logging
aws s3api put-bucket-logging \
  --bucket terraform-state-dev \
  --bucket-logging-status '{
    "LoggingEnabled": {
      "TargetBucket": "terraform-state-logs"
    }
  }'

# Review logs regularly
aws s3 sync s3://terraform-audit-logs /local/audit-logs
```

### 9. Secret Rotation

Rotate credentials regularly:

```bash
# Rotate IAM access keys every 90 days
aws iam create-access-key --user-name jenkins
aws iam delete-access-key --user-name jenkins --access-key-id KEY_TO_DELETE

# Update Secrets Manager
aws secretsmanager rotate-secret \
  --secret-id dev/terraform-env-vars \
  --rotation-rules '{"AutomaticallyAfterDays": 30}'

# Rotate SSH keys
ssh-keygen -t rsa -b 4096 -N "new-passphrase" -f ~/.ssh/terraform-key
```

### 10. Network Security

Minimize network exposure:

```hcl
# Restrict SSH to known IPs only
ingress_rules = [
  {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_OFFICE_IP/32"]  # Not 0.0.0.0/0
    description = "SSH from office"
  }
]

# Use VPC endpoints for private S3 access
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = [aws_route_table.private.id]
}
```

## Compliance Checklist

- [ ] No AWS credentials in Git repository
- [ ] No secrets in Jenkinsfile
- [ ] IAM policies follow least privilege
- [ ] S3 state bucket has encryption enabled
- [ ] S3 state bucket has versioning enabled
- [ ] S3 state bucket blocks public access
- [ ] DynamoDB state locking table exists
- [ ] CloudTrail enabled for audit logging
- [ ] Secrets Manager used for sensitive values
- [ ] Separate state files per environment
- [ ] Prod deployments require approval
- [ ] All IAM access keys rotated < 90 days
- [ ] Network access restricted (no 0.0.0.0/0 for SSH)
- [ ] Jenkins runs with IAM role (not hardcoded keys)
- [ ] .gitignore prevents credential commits

## Incident Response

### If Credentials Are Accidentally Committed

1. **IMMEDIATELY** rotate the compromised credentials
   ```bash
   # Disable access key
   aws iam update-access-key-status \
     --user-name jenkins \
     --access-key-id COMPROMISED_KEY \
     --status Inactive
   
   # Create new access key
   aws iam create-access-key --user-name jenkins
   ```

2. Force GitHub to reject commits with old credentials
   ```bash
   git filter-branch --tree-filter '
     git rm -f --cached --ignore-unmatch */*.tfvars
     git rm -f --cached --ignore-unmatch ~/.aws/credentials
   ' HEAD
   ```

3. Review CloudTrail for any unauthorized access
   ```bash
   aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=jenkins
   ```

4. Notify security team and log incident

### If State File Is Compromised

1. **Immediately** backup state
   ```bash
   terraform state pull > terraform.tfstate.backup
   ```

2. Review what information is exposed
   ```bash
   terraform state show -json | jq '.values.outputs'
   ```

3. Rotate any exposed secrets
   ```bash
   # Manually update Secrets Manager
   aws secretsmanager update-secret --secret-id dev/terraform-env-vars
   ```

4. Re-apply Terraform to update resource metadata
   ```bash
   terraform apply -refresh-only
   ```

## Monitoring and Alerting

Set up CloudWatch alarms for suspicious activity:

```bash
# Alert on failed Terraform state access
aws cloudwatch put-metric-alarm \
  --alarm-name TerraformStateAccessFailures \
  --alarm-description "Alert on S3 access failures to state bucket" \
  --metric-name 4xxErrors \
  --namespace AWS/S3 \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold
```

## Related Documentation

- [Backend Setup Guide](./BACKEND_SETUP.md)
- [Jenkins Configuration Guide](./JENKINS_CONFIGURATION.md)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Terraform Security Best Practices](https://www.terraform.io/docs/language/state/sensitive-data.html)

