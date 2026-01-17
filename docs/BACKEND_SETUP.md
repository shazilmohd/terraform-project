# Backend Infrastructure Setup Guide

This guide explains how to set up the AWS infrastructure required for Terraform state management and Jenkins authentication.

## Overview

The Terraform state backend requires:
- **S3 Bucket** for storing Terraform state files
- **DynamoDB Table** for state locking (prevents concurrent modifications)
- **IAM Role** for Jenkins to authenticate without hardcoded credentials

## Prerequisites

- AWS account with administrative access (for initial setup)
- AWS CLI v2 installed
- `jq` for JSON parsing (optional)

## Step 1: Create S3 Bucket for Terraform State

Run these commands to create an S3 bucket for each environment:

```bash
# Variables
REGION="ap-south-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create S3 bucket for dev environment
aws s3api create-bucket \
  --bucket "terraform-state-dev-${AWS_ACCOUNT_ID}" \
  --region "${REGION}" \
  --create-bucket-configuration LocationConstraint="${REGION}"

# Create S3 bucket for stage environment
aws s3api create-bucket \
  --bucket "terraform-state-stage-${AWS_ACCOUNT_ID}" \
  --region "${REGION}" \
  --create-bucket-configuration LocationConstraint="${REGION}"

# Create S3 bucket for prod environment
aws s3api create-bucket \
  --bucket "terraform-state-prod-${AWS_ACCOUNT_ID}" \
  --region "${REGION}" \
  --create-bucket-configuration LocationConstraint="${REGION}"
```

## Step 2: Enable S3 Bucket Versioning and Encryption

Enable versioning and encryption for each bucket:

```bash
# Enable versioning
for BUCKET in "terraform-state-dev-${AWS_ACCOUNT_ID}" \
              "terraform-state-stage-${AWS_ACCOUNT_ID}" \
              "terraform-state-prod-${AWS_ACCOUNT_ID}"; do
  
  aws s3api put-bucket-versioning \
    --bucket "${BUCKET}" \
    --versioning-configuration Status=Enabled
  
  # Enable default encryption
  aws s3api put-bucket-encryption \
    --bucket "${BUCKET}" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'
  
  # Block public access
  aws s3api put-public-access-block \
    --bucket "${BUCKET}" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
done
```

## Step 3: Create DynamoDB Table for State Locking

Create a DynamoDB table for storing state locks:

```bash
aws dynamodb create-table \
  --table-name "terraform-locks" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${REGION}"

# Wait for table to be created
aws dynamodb wait table-exists \
  --table-name "terraform-locks" \
  --region "${REGION}"

echo "DynamoDB table created successfully"
```

## Step 4: Create IAM Role for Jenkins

Create an IAM role that Jenkins will assume:

```bash
# Create the trust policy document
cat > /tmp/jenkins-trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT_ID:user/jenkins"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Replace ACCOUNT_ID with actual account ID
sed -i "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" /tmp/jenkins-trust-policy.json

# Create the role
aws iam create-role \
  --role-name "jenkins-terraform-role" \
  --assume-role-policy-document file:///tmp/jenkins-trust-policy.json \
  --description "Role for Jenkins to deploy infrastructure with Terraform"
```

## Step 5: Create IAM Policy for Jenkins

Create and attach a policy for Jenkins:

```bash
# Create policy document
cat > /tmp/jenkins-terraform-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateBucketAccess",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketVersioning",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-dev-*",
        "arn:aws:s3:::terraform-state-stage-*",
        "arn:aws:s3:::terraform-state-prod-*"
      ]
    },
    {
      "Sid": "TerraformStateObjectAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetObjectVersion"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-dev-*/*",
        "arn:aws:s3:::terraform-state-stage-*/*",
        "arn:aws:s3:::terraform-state-prod-*/*"
      ]
    },
    {
      "Sid": "TerraformStateLocking",
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-locks"
    },
    {
      "Sid": "EC2Permissions",
      "Effect": "Allow",
      "Action": [
        "ec2:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "VPCPermissions",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeRouteTables",
        "ec2:DescribeInternetGateways",
        "ec2:CreateVpc",
        "ec2:CreateSubnet",
        "ec2:CreateSecurityGroup",
        "ec2:CreateNetworkInterface",
        "ec2:CreateRouteTable",
        "ec2:CreateInternetGateway",
        "ec2:ModifyVpc*",
        "ec2:DeleteVpc",
        "ec2:DeleteSubnet",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteRouteTable",
        "ec2:DeleteInternetGateway"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMPermissions",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:CreateInstanceProfile",
        "iam:CreatePolicy",
        "iam:AttachRolePolicy",
        "iam:PutRolePolicy",
        "iam:AddRoleToInstanceProfile",
        "iam:GetRole",
        "iam:GetInstanceProfile",
        "iam:GetPolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:DeleteRole",
        "iam:DeleteInstanceProfile",
        "iam:DeletePolicy",
        "iam:DetachRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:PassRole"
      ],
      "Resource": "arn:aws:iam::*:role/*",
      "Condition": {
        "StringLike": {
          "aws:RequestedRegion": "ap-south-1"
        }
      }
    },
    {
      "Sid": "SecretsManagerAccess",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:*/terraform-env-vars"
    },
    {
      "Sid": "ReadOnlyViewPermissions",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "iam:List*",
        "iam:Get*",
        "s3:List*",
        "dynamodb:Describe*",
        "secretsmanager:List*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create policy
aws iam create-policy \
  --policy-name "jenkins-terraform-policy" \
  --policy-document file:///tmp/jenkins-terraform-policy.json \
  --description "Policy for Jenkins to deploy infrastructure"

# Attach policy to role
aws iam attach-role-policy \
  --role-name "jenkins-terraform-role" \
  --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/jenkins-terraform-policy"
```

## Step 6: Create Jenkins IAM User (if Jenkins runs on bare metal)

If Jenkins doesn't run on EC2, create an IAM user instead:

```bash
# Create IAM user for Jenkins
aws iam create-user --user-name jenkins

# Create access key
aws iam create-access-key --user-name jenkins > /tmp/jenkins-credentials.json

# Display credentials (SAVE THESE SECURELY)
cat /tmp/jenkins-credentials.json

# Attach inline policy to user
aws iam put-user-policy \
  --user-name jenkins \
  --policy-name "jenkins-terraform-policy" \
  --policy-document file:///tmp/jenkins-terraform-policy.json
```

**IMPORTANT:** Store the access key and secret in a secure location (e.g., AWS Secrets Manager or Jenkins credentials).

## Step 7: Create Secrets Manager Secrets for Environment Variables

Create a secret in Secrets Manager for each environment:

```bash
# Create dev environment secret
aws secretsmanager create-secret \
  --name "dev/terraform-env-vars" \
  --description "Terraform variables for dev environment" \
  --secret-string '{
    "vpc_cidr": "10.0.0.0/16",
    "public_subnet_cidrs": "[\"10.0.1.0/24\", \"10.0.2.0/24\"]",
    "private_subnet_cidrs": "[\"10.0.10.0/24\", \"10.0.11.0/24\"]",
    "instance_type": "t3.micro",
    "instance_count": 1,
    "key_pair_name": ""
  }'

# Create stage environment secret
aws secretsmanager create-secret \
  --name "stage/terraform-env-vars" \
  --description "Terraform variables for stage environment" \
  --secret-string '{
    "vpc_cidr": "10.1.0.0/16",
    "public_subnet_cidrs": "[\"10.1.1.0/24\", \"10.1.2.0/24\"]",
    "private_subnet_cidrs": "[\"10.1.10.0/24\", \"10.1.11.0/24\"]",
    "instance_type": "t3.small",
    "instance_count": 2,
    "key_pair_name": ""
  }'

# Create prod environment secret
aws secretsmanager create-secret \
  --name "prod/terraform-env-vars" \
  --description "Terraform variables for prod environment" \
  --secret-string '{
    "vpc_cidr": "10.2.0.0/16",
    "public_subnet_cidrs": "[\"10.2.1.0/24\", \"10.2.2.0/24\"]",
    "private_subnet_cidrs": "[\"10.2.10.0/24\", \"10.2.11.0/24\"]",
    "instance_type": "t3.small",
    "instance_count": 2,
    "key_pair_name": ""
  }'
```

## Step 8: Update Terraform Backend Configuration

In your `env/*/backend.tf` files, update the bucket names to match your actual bucket names:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-dev-ACCOUNT_ID"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

Replace `ACCOUNT_ID` with your actual AWS account ID.

## Step 9: Update Jenkins Configuration

For Jenkins on EC2, attach the role created in Step 4:

```bash
# Attach role to EC2 instance
aws ec2 associate-iam-instance-profile \
  --iam-instance-profile Name=jenkins-instance-profile \
  --instance-id i-1234567890abcdef0
```

For Jenkins on bare metal, configure AWS credentials:

```bash
# Create ~/.aws/credentials with Jenkins user's access key
cat > ~/.aws/credentials <<EOF
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
region = ap-south-1
EOF

chmod 600 ~/.aws/credentials
```

## Verification

Verify the setup is complete:

```bash
# Test S3 bucket access
aws s3 ls s3://terraform-state-dev-${AWS_ACCOUNT_ID}/

# Test DynamoDB access
aws dynamodb describe-table --table-name terraform-locks

# Test Secrets Manager access
aws secretsmanager get-secret-value --secret-id dev/terraform-env-vars

# Test EC2 permissions
aws ec2 describe-vpcs
```

## Troubleshooting

**Problem:** "Access Denied" errors when running Terraform

**Solution:** 
1. Verify IAM user/role has correct policies attached
2. Check S3 bucket policies don't restrict access
3. Ensure DynamoDB table exists and is in correct region
4. Check AWS credentials are correctly configured

**Problem:** State lock timeout

**Solution:**
1. Check DynamoDB table is responding
2. Remove stale locks: `aws dynamodb scan --table-name terraform-locks`
3. Delete stale lock if necessary: `aws dynamodb delete-item --table-name terraform-locks --key '{"LockID": {"S": "lock-id"}}'`

**Problem:** Bucket already exists error

**Solution:** Bucket names must be globally unique. Use your account ID or a unique prefix to avoid conflicts.

## Security Best Practices

1. **Never commit credentials** to Git (covered by .gitignore)
2. **Rotate access keys** regularly (every 90 days)
3. **Use MFA** for AWS console access
4. **Restrict S3 bucket policies** - Block public access
5. **Enable versioning** on state buckets
6. **Enable encryption** on all S3 buckets and DynamoDB
7. **Monitor CloudTrail** for API calls to state resources
8. **Use IAM roles** instead of hardcoded credentials whenever possible

## Cleanup (Destroy Infrastructure)

To remove all resources:

```bash
# Delete Secrets Manager secrets
aws secretsmanager delete-secret --secret-id dev/terraform-env-vars --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id stage/terraform-env-vars --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id prod/terraform-env-vars --force-delete-without-recovery

# Delete DynamoDB table
aws dynamodb delete-table --table-name terraform-locks

# Delete S3 buckets (must be empty first)
aws s3 rm s3://terraform-state-dev-${AWS_ACCOUNT_ID} --recursive
aws s3 rm s3://terraform-state-stage-${AWS_ACCOUNT_ID} --recursive
aws s3 rm s3://terraform-state-prod-${AWS_ACCOUNT_ID} --recursive

aws s3api delete-bucket --bucket terraform-state-dev-${AWS_ACCOUNT_ID}
aws s3api delete-bucket --bucket terraform-state-stage-${AWS_ACCOUNT_ID}
aws s3api delete-bucket --bucket terraform-state-prod-${AWS_ACCOUNT_ID}

# Delete IAM resources
aws iam detach-role-policy --role-name jenkins-terraform-role --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/jenkins-terraform-policy
aws iam delete-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/jenkins-terraform-policy
aws iam delete-role --role-name jenkins-terraform-role

# Or if using IAM user:
aws iam delete-access-key --user-name jenkins --access-key-id KEY_ID
aws iam delete-user-policy --user-name jenkins --policy-name jenkins-terraform-policy
aws iam delete-user --user-name jenkins
```

