# Jenkins Configuration Guide

This guide explains how to configure Jenkins to work with Terraform and AWS without storing credentials in the Jenkinsfile.

## Overview

The secure approach uses **IAM roles** (for EC2) or **credential chain** (for bare metal) so Jenkins never directly manages AWS credentials.

## Prerequisites

- Jenkins instance already set up
- AWS CLI installed on Jenkins machine
- Access to AWS account to create IAM roles/users

## Option A: Jenkins on EC2 Instance (Recommended)

### Step 1: Create IAM Instance Profile

Follow the instructions in [BACKEND_SETUP.md](./BACKEND_SETUP.md#step-4-create-iam-role-for-jenkins) to create an IAM role called `jenkins-terraform-role`.

### Step 2: Attach Role to Jenkins EC2 Instance

```bash
# Get Jenkins instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=jenkins" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

# Create instance profile
aws iam create-instance-profile \
  --instance-profile-name jenkins-instance-profile

# Add role to instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name jenkins-instance-profile \
  --role-name jenkins-terraform-role

# Attach profile to instance
aws ec2 associate-iam-instance-profile \
  --iam-instance-profile Name=jenkins-instance-profile \
  --instance-id ${INSTANCE_ID}
```

### Step 3: Restart Jenkins

```bash
sudo systemctl restart jenkins
# or
sudo service jenkins restart
```

After restart, Jenkins will automatically use the IAM role for AWS access.

### Verification

SSH into the Jenkins instance and verify:

```bash
# Should return instance role credentials
aws sts get-caller-identity

# Should show Jenkins user
whoami

# Should be able to access S3
aws s3 ls s3://terraform-state-dev-ACCOUNT_ID/
```

## Option B: Jenkins on Bare Metal / Non-EC2

### Step 1: Create IAM User

Follow the instructions in [BACKEND_SETUP.md](./BACKEND_SETUP.md#step-6-create-jenkins-iam-user-if-jenkins-runs-on-bare-metal) to create an IAM user called `jenkins`.

### Step 2: Configure AWS Credentials

Create the AWS credentials file for the Jenkins user:

```bash
# As the Jenkins user or with sudo
sudo -u jenkins bash <<'EOF'
mkdir -p ~/.aws

cat > ~/.aws/credentials <<'CREDS'
[default]
aws_access_key_id = YOUR_ACCESS_KEY_HERE
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY_HERE
region = ap-south-1
CREDS

chmod 600 ~/.aws/credentials
EOF
```

**NEVER** commit the credentials file to Git!

### Step 3: Verify Jenkins User Configuration

```bash
# Switch to Jenkins user
sudo -u jenkins bash

# Test AWS CLI access
aws sts get-caller-identity

# Should return Jenkins user info
```

## Jenkinsfile Configuration

### Before (Insecure)

```groovy
environment {
    AWS_CREDENTIALS = credentials('aws-bootstrap-creds')  // ❌ WRONG
}
```

### After (Secure)

```groovy
// No AWS_CREDENTIALS in environment!
// AWS CLI will use IAM role or ~/.aws/credentials automatically
```

### Complete Safe Jenkinsfile Example

```groovy
pipeline {
    agent any

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'stage', 'prod'],
            description: 'Environment to deploy to'
        )
        
        choice(
            name: 'ACTION',
            choices: ['PLAN', 'APPLY', 'DESTROY'],
            description: 'Terraform action to perform'
        )
        
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: 'Skip manual approval for terraform apply'
        )
        
        string(
            name: 'AWS_REGION',
            defaultValue: 'ap-south-1',
            description: 'AWS region for deployment'
        )
    }

    environment {
        // NO hardcoded AWS credentials!
        TF_WORKING_DIR = "env/${params.ENVIRONMENT}"
        AWS_REGION = "${params.AWS_REGION}"
        TF_LOG = 'INFO'
        BUILD_TIMESTAMP = sh(script: "date +%Y%m%d_%H%M%S", returnStdout: true).trim()
        ENVIRONMENT = "${params.ENVIRONMENT}"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10', daysToKeepStr: '30'))
        disableConcurrentBuilds()
        timeout(time: 1, unit: 'HOURS')
        timestamps()
    }

    stages {
        stage('Pre-Validation') {
            steps {
                script {
                    sh '''
                        echo "Checking prerequisites..."
                        
                        # Verify Terraform is installed
                        terraform version
                        
                        # Verify AWS CLI is installed
                        aws --version
                        
                        # Verify AWS credentials are available (via IAM role or ~/.aws/credentials)
                        echo "Checking AWS credentials..."
                        aws sts get-caller-identity
                        
                        # Verify Terraform working directory exists
                        if [ ! -d "${TF_WORKING_DIR}" ]; then
                            echo "ERROR: ${TF_WORKING_DIR} directory not found"
                            exit 1
                        fi
                        
                        echo "✓ All pre-validation checks passed"
                    '''
                }
            }
        }

        stage('Terraform Init') {
            steps {
                script {
                    dir("${TF_WORKING_DIR}") {
                        sh '''
                            terraform init -upgrade -input=false
                        '''
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                script {
                    dir("${TF_WORKING_DIR}") {
                        sh '''
                            terraform plan \
                                -input=false \
                                -var-file=terraform.tfvars \
                                -out=tfplan_${BUILD_TIMESTAMP}
                        '''
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'APPLY' }
            }
            steps {
                script {
                    // Manual approval for production
                    if (params.ENVIRONMENT == 'prod' && !params.AUTO_APPROVE) {
                        timeout(time: 30, unit: 'MINUTES') {
                            input message: 'Deploy to PRODUCTION?', ok: 'Deploy'
                        }
                    }
                    
                    dir("${TF_WORKING_DIR}") {
                        sh '''
                            terraform apply \
                                -input=false \
                                -auto-approve \
                                tfplan_${BUILD_TIMESTAMP}
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            // Clean up sensitive files
            dir("${TF_WORKING_DIR}") {
                sh '''
                    rm -f tfplan_* || true
                '''
            }
        }
    }
}
```

## Jenkins Global Configuration

### Configure Jenkins System Settings

1. Go to **Manage Jenkins** → **Configure System**
2. Look for **Terraform** section (if you have Terraform plugin installed)
3. Set Terraform path: `/usr/local/bin/terraform`

### (Optional) Install Terraform Plugin

1. Go to **Manage Jenkins** → **Manage Plugins**
2. Search for "Terraform"
3. Install **Terraform Plugin** (optional, Jenkins can use shell steps)

## AWS CLI Configuration in Jenkins

Jenkins inherits AWS credentials from:

1. **IAM Instance Role** (EC2) - highest priority
2. **`~/.aws/credentials`** file (bare metal)
3. **Environment variables** (`AWS_ACCESS_KEY_ID`, etc.) - NOT recommended

Verify the order:

```bash
# This command shows which credentials are in use
aws sts get-caller-identity
```

## Troubleshooting

### Problem: "Unable to locate credentials"

**Cause:** Jenkins cannot find AWS credentials

**Solution:**
- **EC2:** Verify IAM role is attached to instance
  ```bash
  aws ec2 describe-iam-instance-profile-associations --filters Name=instance-id,Values=i-xxxxx
  ```
- **Bare metal:** Verify `~/.aws/credentials` exists and has correct permissions
  ```bash
  ls -la ~/.aws/credentials  # Should show -rw------- (600)
  ```

### Problem: "Access Denied" when accessing S3

**Cause:** IAM user/role lacks required permissions

**Solution:**
1. Verify IAM policy is attached
2. Check policy includes S3, DynamoDB, EC2 permissions
3. Check resource ARNs are correct

### Problem: Jenkins Job Hangs During `terraform init`

**Cause:** State locking issue or network problem

**Solution:**
1. Check DynamoDB table exists and is reachable
2. Check network connectivity to AWS
3. Review Jenkins logs for detailed error

### Problem: Terraform Plan Contains Sensitive Values

**Cause:** Secrets Manager values are being logged

**Solution:**
1. Mark sensitive outputs in Terraform
2. Configure Jenkins to not log sensitive data
3. Review security group rules in Jenkinsfile

## Security Best Practices

1. **Never** store AWS credentials in Jenkinsfile or Jenkins configuration
2. **Always** use IAM roles for EC2 Jenkins instances
3. **Restrict** Jenkins IAM policy to only required permissions
4. **Enable** MFA for Jenkins system user (on bare metal)
5. **Rotate** IAM access keys quarterly
6. **Audit** Jenkins job logs for credential leaks
7. **Monitor** S3 access via CloudTrail
8. **Use VPC endpoints** for private S3 access (advanced)

## Environment-Specific Credentials

Each environment (dev, stage, prod) can have different access levels:

```json
{
  "dev": {
    "allow_destroy": true,
    "require_approval": false
  },
  "stage": {
    "allow_destroy": true,
    "require_approval": true
  },
  "prod": {
    "allow_destroy": false,
    "require_approval": true,
    "requires_specific_approver": true
  }
}
```

Configure this in your Jenkinsfile's approval stages.

