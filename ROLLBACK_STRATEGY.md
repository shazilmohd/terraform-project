# Rollback Strategy Analysis & Implementation Guide

## Executive Summary

This document provides a comprehensive analysis of rollback capabilities for the Terraform-based infrastructure project and recommends implementation strategies suited to the current architecture.

---

## Table of Contents

1. [Project Structure Analysis](#project-structure-analysis)
2. [Current State Management](#current-state-management)
3. [Rollback Approaches](#rollback-approaches)
4. [Recommended Implementation](#recommended-implementation)
5. [Implementation Roadmap](#implementation-roadmap)

---

## Project Structure Analysis

### 1. Architecture Overview

```
Terraform-Project/
├── modules/                          # Reusable, parameterized infrastructure
│   ├── compute/ec2/                 # EC2 instances (count-based scaling)
│   ├── networking/vpc/              # VPC + subnets (multi-AZ)
│   ├── networking/security_group/   # Security rules (ingress/egress)
│   └── secrets/secret_manager/      # Configuration secrets (external source)
│
├── env/                             # Environment-specific configs (3 envs)
│   ├── dev/
│   │   ├── main.tf                  # Resource instantiation
│   │   ├── variables.tf             # Variable definitions
│   │   ├── outputs.tf               # Output definitions
│   │   ├── terraform.tfvars         # Non-sensitive values (committed)
│   │   ├── terraform.tfstate        # State file (NOT committed)
│   │   └── backend.tf               # S3 backend config
│   ├── stage/                       # (same structure)
│   └── prod/                        # (same structure)
│
├── scripts/                         # Deployment utilities
│   ├── install_apache2.sh           # User data script
│   └── load_jenkins_config.sh       # Config management
│
└── Jenkinsfile                      # CI/CD pipeline (18 stages)
```

### 2. Multi-Environment Setup

| Aspect | Dev | Stage | Prod |
|--------|-----|-------|------|
| **Instances** | 1 × t3.micro | 2 × t3.micro | 2 × t3.micro |
| **VPC CIDR** | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| **Subnets** | 1 public | 2 pub + 2 pri | 2 pub + 2 pri |
| **Secret Creation** | Reuse (false) | Create (true) | Create (true) |
| **Destroy Protection** | None | None | Manual approval |
| **State Backend** | S3: `terraform-state-1768505102` | S3: same bucket | S3: same bucket |
| **State Locking** | DynamoDB: `terraform-locks` | DynamoDB: same table | DynamoDB: same table |

### 3. State Management Strategy

**Current Setup:**
- **Backend:** AWS S3 (centralized)
  - Bucket: `terraform-state-1768505102`
  - Keys: `dev/terraform.tfstate`, `stage/terraform.tfstate`, `prod/terraform.tfstate`
  - Encryption: ✅ Enabled (AES-256)
  - Versioning: ❓ **Need to verify if enabled**
  
- **State Locking:** DynamoDB (`terraform-locks`)
  - Prevents concurrent modifications
  - Automatic unlock after timeout

- **Local State Files:** Excluded from git (`.gitignore`)
  - State contains sensitive data (passwords, API keys)
  - Only tfvars (non-sensitive) are committed

### 4. Infrastructure Components

**Managed Resources (Tracked in State):**
1. **Networking** (VPC Module)
   - VPC with custom CIDR
   - Public subnets (NAT gateway in stage/prod)
   - Private subnets (stage/prod only)
   - Internet Gateway + Route tables

2. **Security** (Security Group Module)
   - Ingress: SSH (22), HTTP (80), HTTPS (443)
   - Egress: All traffic allowed
   - VPC-bound (can't be reused across VPCs)

3. **IAM** (EC2 Module)
   - Instance Role (IAM role for EC2 to access services)
   - Instance Profile (attaches role to EC2)
   - Inline policy (permissions for specific services)

4. **Compute** (EC2 Module)
   - EC2 instances (count-based: 1, 2, or 2 per env)
   - Latest Ubuntu 22.04 LTS AMI
   - User data script (Apache2 installation)
   - Root volume (20GB gp2)

5. **Secrets Management**
   - AWS Secrets Manager entries (per env)
   - Contains: app_name, app_version, contact_email
   - Created/managed by Terraform

### 5. Deployment Pipeline Structure

```
Pre-Validation
    ↓
Parameter Validation (ENVIRONMENT, ACTION, AUTO_APPROVE)
    ↓
Terraform Init (S3 backend setup, state lock acquisition)
    ↓
Terraform Validate (HCL syntax check)
    ↓
Terraform Format Check (auto-format modules & env)
    ↓
Terraform Plan (dry-run: show all changes)
    ↓
Review Plan (display plan summary)
    ↓
Approval (manual gate: 30 min for dev/stage, 60 min for prod)
    ↓
Terraform Apply (create/update resources)
    ↓
Promote to Stage (auto-trigger if dev succeeds)
    ↓
Terraform Destroy (only for ACTION=DESTROY, blocks prod)
    ↓
Parallel Destroy (all 3 envs simultaneously if parallel-destroy-all)
    ↓
Output Artifacts (archive plans/logs)
```

---

## Current State Management

### State File Contents

Each state file contains:
```json
{
  "version": 4,
  "terraform_version": "1.5.0",
  "serial": 42,  // Incremented on each apply
  "lineage": "uuid-unique-per-state",
  "outputs": { ... },
  "resources": [
    // All managed resources with their attributes
    // - VPC, subnets, route tables, IGW
    // - Security groups with rules
    // - IAM roles, policies, instance profiles
    // - EC2 instances with network interfaces
    // - EBS volumes, Elastic IPs
    // - Secrets Manager entries
  ]
}
```

### Key Vulnerabilities

1. **Single State File per Environment**
   - Monolithic state (all resources in one file)
   - Large file → slow performance
   - One resource error → entire stack at risk

2. **No State History**
   - S3 versioning not explicitly enabled
   - Previous versions of state might not be available
   - Can't easily check what changed in past

3. **State Lock Timeout**
   - DynamoDB locks auto-expire after duration
   - Long-running operations could release lock early
   - Concurrent applies might proceed simultaneously

4. **Local Backup Absence**
   - No local state backups in Jenkins
   - State only backed up by S3 (if versioning enabled)
   - No local snapshots between deployments

---

## Rollback Approaches

### Approach 1: Terraform State Rollback (Primary)

**How it works:**
- Revert `terraform.tfstate` to a previous version
- Terraform sees old resource definitions as current
- Next `terraform apply` destroys new resources, recreates old ones

**Advantages:**
- ✅ Works for ANY change (resource creation, deletion, modification)
- ✅ Complete infrastructure state restoration
- ✅ Fast execution (state-based, not resource-based)
- ✅ Maintains resource IDs (less disruption)

**Disadvantages:**
- ❌ Requires S3 versioning enabled
- ❌ Breaks external dependencies (if resources reference newer ones)
- ❌ Risk of data loss if state points to older DB configurations

**Implementation Complexity:** Low
**Time to Restore:** 5-15 minutes
**Data Risk:** Medium (depends on what resources were affected)

### Approach 2: Terraform Destroy → Reapply Previous Version (Secondary)

**How it works:**
- Run `terraform destroy` to remove all new resources
- Checkout previous version of code from git
- Run `terraform apply` to recreate infrastructure

**Advantages:**
- ✅ No state file manipulation required
- ✅ Guaranteed clean state
- ✅ Code-based (easier to audit)

**Disadvantages:**
- ❌ Downtime during destroy/recreate (10-20 minutes)
- ❌ Resources get new IDs (DNS, security group IDs change)
- ❌ Dependent systems break (load balancers, DNS entries)
- ❌ Risk of data loss on EBS volumes

**Implementation Complexity:** Low
**Time to Restore:** 15-30 minutes
**Data Risk:** High (deletes actual infrastructure)

### Approach 3: Blue-Green Deployment (Advanced)

**How it works:**
- Deploy new version (green) in parallel with current (blue)
- Test green infrastructure
- Switch traffic/DNS to green on success
- Keep blue as rollback target (destroys old after N hours)

**Advantages:**
- ✅ Zero downtime
- ✅ Easy rollback (just switch traffic back)
- ✅ Can test new version before cutover

**Disadvantages:**
- ❌ Double resource costs during switchover
- ❌ Complex implementation (load balancers, DNS, health checks)
- ❌ Requires application-level awareness

**Implementation Complexity:** High
**Time to Restore:** 1-2 minutes (just traffic switch)
**Data Risk:** Low (old infrastructure still running)

### Approach 4: Git-Based Rollback (Lightweight)

**How it works:**
- Revert code changes in git
- Re-run terraform apply with reverted code
- Terraform automatically adjusts resources to match old configuration

**Advantages:**
- ✅ Simple, git-native workflow
- ✅ Clear audit trail (git history)
- ✅ Works for code-driven changes

**Disadvantages:**
- ❌ Doesn't help with state corruption
- ❌ Manual git operations needed
- ❌ Requires understanding of git history

**Implementation Complexity:** Low
**Time to Restore:** 10-20 minutes
**Data Risk:** Medium (depending on code changes)

---

## Recommended Implementation

### For This Project: Hybrid Approach

**Primary Strategy:** Terraform State Rollback (with backup)
**Secondary Strategy:** Git-Based Rollback (for code issues)
**Tertiary Strategy:** Destroy → Reapply (last resort)

### Implementation Components

#### 1. Enable S3 State Versioning

```bash
# Enable versioning on terraform-state-1768505102 bucket
aws s3api put-bucket-versioning \
  --bucket terraform-state-1768505102 \
  --versioning-configuration Status=Enabled
```

**Purpose:**
- Automatically keeps version history of state files
- Allows retrieval of previous state versions
- No additional cost (minimal)

#### 2. State Backup Script

**File:** `scripts/backup_terraform_state.sh`

```bash
#!/bin/bash
# Backs up current state from S3 to local folder + git

ENVIRONMENTS=("dev" "stage" "prod")
BACKUP_DIR=".terraform-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

for env in "${ENVIRONMENTS[@]}"; do
  aws s3 cp \
    s3://terraform-state-1768505102/$env/terraform.tfstate \
    "$BACKUP_DIR/terraform-$env-$TIMESTAMP.tfstate"
  
  echo "Backed up $env state to $BACKUP_DIR/terraform-$env-$TIMESTAMP.tfstate"
done

# Commit backups to git (for audit trail)
git add "$BACKUP_DIR"
git commit -m "State backup: $TIMESTAMP"
git push
```

**Usage:** Run before every production apply

#### 3. State Rollback Script

**File:** `scripts/rollback_terraform_state.sh`

```bash
#!/bin/bash
# Rolls back Terraform state to a previous version

ENVIRONMENT=$1
BACKUP_FILE=$2  # Path to .tfstate backup

if [ -z "$ENVIRONMENT" ] || [ -z "$BACKUP_FILE" ]; then
  echo "Usage: ./scripts/rollback_terraform_state.sh <env> <backup_file>"
  echo "Example: ./scripts/rollback_terraform_state.sh prod .terraform-backups/terraform-prod-20260117_120000.tfstate"
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file not found: $BACKUP_FILE"
  exit 1
fi

# Verify environment directory exists
if [ ! -d "env/$ENVIRONMENT" ]; then
  echo "Error: Environment directory not found: env/$ENVIRONMENT"
  exit 1
fi

echo "⚠️  WARNING: This will rollback $ENVIRONMENT to a previous state"
echo "Backup file: $BACKUP_FILE"
read -p "Type 'ROLLBACK' to proceed: " confirmation

if [ "$confirmation" != "ROLLBACK" ]; then
  echo "Rollback cancelled"
  exit 0
fi

# Upload previous state to S3
aws s3 cp "$BACKUP_FILE" \
  "s3://terraform-state-1768505102/$ENVIRONMENT/terraform.tfstate"

echo "✓ State rolled back. Run: terraform apply (to reconcile resources)"
```

**Usage:** `./scripts/rollback_terraform_state.sh prod .terraform-backups/terraform-prod-20260117_120000.tfstate`

#### 4. Jenkins Rollback Stage

**Addition to Jenkinsfile:**

```groovy
pipeline {
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'stage', 'prod', 'parallel-destroy-all', 'rollback'],
            description: 'Environment or action to perform'
        )
        
        choice(
            name: 'ACTION',
            choices: ['PLAN', 'APPLY', 'DESTROY', 'ROLLBACK'],
            description: 'Terraform action to perform'
        )
        
        string(
            name: 'ROLLBACK_FILE',
            defaultValue: '',
            description: 'Path to state backup for rollback (e.g., .terraform-backups/terraform-prod-20260117.tfstate)'
        )
    }
    
    stages {
        stage('State Rollback') {
            when {
                expression { params.ACTION == 'ROLLBACK' }
            }
            steps {
                script {
                    echo "========== TERRAFORM STATE ROLLBACK =========="
                    
                    timeout(time: 15, unit: 'MINUTES') {
                        input message: '''
                        
                        ⚠️  CRITICAL: STATE ROLLBACK OPERATION ⚠️
                        
                        This will restore Terraform state from a backup.
                        The next 'terraform apply' will adjust infrastructure to match rolled-back state.
                        
                        Environment: ''' + params.ENVIRONMENT + '''
                        Backup File: ''' + params.ROLLBACK_FILE + '''
                        
                        This action affects real infrastructure.
                        Ensure backup file is correct before proceeding.
                        
                        Type "ROLLBACK" to confirm:
                        ''',
                        ok: 'CONFIRM ROLLBACK'
                    }
                    
                    sh '''
                        bash scripts/rollback_terraform_state.sh \
                            "${ENVIRONMENT}" "${ROLLBACK_FILE}"
                    '''
                    
                    echo "✓ State rollback completed"
                    echo "Next steps: Run terraform apply to reconcile infrastructure"
                }
            }
        }
        
        stage('Post-Rollback Reconciliation') {
            when {
                expression { params.ACTION == 'ROLLBACK' }
            }
            steps {
                script {
                    echo "========== Reconciliation Options =========="
                    echo ""
                    echo "1. Run PLAN to preview resource changes"
                    echo "   - Trigger new build: ACTION=PLAN, ENVIRONMENT=${ENVIRONMENT}"
                    echo ""
                    echo "2. Run APPLY to reconcile infrastructure"
                    echo "   - Trigger new build: ACTION=APPLY, ENVIRONMENT=${ENVIRONMENT}"
                    echo ""
                    echo "3. Review state backup: aws s3 ls s3://terraform-state-1768505102/${ENVIRONMENT}/"
                }
            }
        }
    }
}
```

#### 5. Automated State Backup Before Apply

**Add to Jenkinsfile Terraform Apply stage:**

```groovy
stage('Terraform Apply') {
    steps {
        script {
            dir("${TF_WORKING_DIR}") {
                sh '''
                    # Backup current state before apply (safety measure)
                    BACKUP_DIR=".terraform-backups"
                    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
                    mkdir -p "${BACKUP_DIR}"
                    
                    aws s3 cp \
                        "s3://terraform-state-1768505102/${ENVIRONMENT}/terraform.tfstate" \
                        "${BACKUP_DIR}/terraform-${ENVIRONMENT}-${TIMESTAMP}.tfstate" || true
                    
                    echo "✓ Pre-apply state backup: ${BACKUP_DIR}/terraform-${ENVIRONMENT}-${TIMESTAMP}.tfstate"
                    
                    # Actual apply
                    terraform apply -auto-approve -input=false tfplan_${BUILD_TIMESTAMP}
                '''
            }
        }
    }
}
```

---

## Implementation Roadmap

### Phase 1: Immediate (Week 1-2)

**Priority:** Enable S3 versioning + create backup scripts

```
✓ Enable S3 bucket versioning
✓ Create backup_terraform_state.sh script
✓ Create rollback_terraform_state.sh script
✓ Add scripts to .gitignore
✓ Document rollback procedures
✓ Test rollback process on dev environment
```

**Estimated Effort:** 4-8 hours
**Risk:** Low (read-only operations)

### Phase 2: Jenkins Integration (Week 3-4)

**Priority:** Add rollback stage to Jenkinsfile

```
✓ Add ROLLBACK to ACTION parameter
✓ Add rollback stage to pipeline
✓ Add post-rollback reconciliation stage
✓ Add pre-apply automated backups
✓ Test complete rollback workflow
✓ Create runbook for common scenarios
```

**Estimated Effort:** 8-12 hours
**Risk:** Medium (touches pipeline, but doesn't affect normal operations)

### Phase 3: Monitoring & Alerting (Week 5-6)

**Priority:** Add state change monitoring

```
✓ CloudWatch event for state file changes
✓ SNS notifications on apply operations
✓ State file size tracking (detect corruption)
✓ Backup file status dashboard
✓ Rollback failure alerts
```

**Estimated Effort:** 12-16 hours
**Risk:** Medium (new AWS resources)

### Phase 4: Advanced Features (Week 7-8)

**Priority:** Implement diff comparison and validation

```
✓ State diff comparison (before/after)
✓ Cost impact analysis (if apply would increase costs)
✓ Rollback validation (verify state is valid)
✓ Automated rollback on failed health checks
```

**Estimated Effort:** 16-20 hours
**Risk:** High (complex logic)

---

## Rollback Scenarios & Procedures

### Scenario 1: Wrong Resource Configuration Applied

**Symptoms:**
- Resource created with wrong parameters (e.g., t3.large instead of t3.micro)
- Settings incorrectly applied to production

**Rollback Steps:**
1. Identify backup file timestamp before the bad apply
2. Run: `terraform-jenkins` job with `ACTION=ROLLBACK, ENVIRONMENT=prod, ROLLBACK_FILE=.terraform-backups/terraform-prod-20260117_100000.tfstate`
3. Wait for confirmation prompt
4. Confirm with "ROLLBACK"
5. Run new build with `ACTION=PLAN` to preview changes
6. Review changes (should show removal of bad config)
7. Run `ACTION=APPLY` to reconcile

**Time to Restore:** 10-15 minutes
**Downtime:** Minimal (resources modified in-place)

### Scenario 2: Resources Accidentally Deleted from Code

**Symptoms:**
- Code commit removed resource definition (e.g., security group)
- Terraform plan shows resource destruction
- Caught during review stage before apply

**Rollback Steps (without changing state):**
1. Git revert the commit: `git revert <commit-hash>`
2. Push reverted code to GitHub
3. Run `ACTION=PLAN` with reverted code
4. Verify resource recreation is shown
5. Run `ACTION=APPLY` to recreate

**Time to Restore:** 5-10 minutes
**Downtime:** Minimal

### Scenario 3: State Corruption or Lost Resources

**Symptoms:**
- Terraform can't find resource (CloudTrail shows resource still exists in AWS)
- Apply would delete resource but resource exists
- State file size dramatically increased/decreased

**Rollback Steps:**
1. Identify last known good state backup
2. Run `ACTION=ROLLBACK` with correct backup file
3. Let pipeline reconcile by running `ACTION=APPLY`
4. Terraform will verify all resources match state

**Time to Restore:** 15-20 minutes
**Downtime:** Depends on resource type

### Scenario 4: Multi-Environment Deployment Chain Failed

**Symptoms:**
- Dev deployment succeeded
- Stage auto-promotion failed (due to different config)
- Prod needs to be rolled back

**Rollback Steps:**
1. For prod: Run ROLLBACK stage with prod backup
2. For stage: Check if state is valid; if not, rollback
3. For dev: Rollback if necessary
4. Fix underlying cause (variable mismatch, etc.)
5. Redeploy in correct order

**Time to Restore:** 20-30 minutes
**Downtime:** All three environments potentially affected

---

## Monitoring & Validation

### Health Checks Post-Rollback

```bash
#!/bin/bash
# Validate rollback was successful

ENVIRONMENT=$1

echo "Validating $ENVIRONMENT environment..."

# 1. Check state file integrity
echo "1. Verifying state file..."
aws s3 cp s3://terraform-state-1768505102/$ENVIRONMENT/terraform.tfstate - | \
  jq . > /dev/null && echo "   ✓ State file is valid JSON"

# 2. Check resource counts
echo "2. Checking resource counts..."
EXPECTED_RESOURCES=8  # Adjust based on your setup
ACTUAL_RESOURCES=$(aws s3 cp s3://terraform-state-1768505102/$ENVIRONMENT/terraform.tfstate - | \
  jq '.resources | length')

if [ "$ACTUAL_RESOURCES" -eq "$EXPECTED_RESOURCES" ]; then
  echo "   ✓ Resource count matches ($ACTUAL_RESOURCES)"
else
  echo "   ⚠️  Resource count mismatch (expected: $EXPECTED_RESOURCES, actual: $ACTUAL_RESOURCES)"
fi

# 3. Verify EC2 instances
echo "3. Checking EC2 instances..."
RUNNING_COUNT=$(aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=$ENVIRONMENT" "Name=instance-state-name,Values=running" \
  --query 'length(Reservations[*].Instances[])' \
  --region ap-south-1)

echo "   Running instances: $RUNNING_COUNT"

# 4. Verify security groups
echo "4. Checking security groups..."
SG_COUNT=$(aws ec2 describe-security-groups \
  --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
  --query 'length(SecurityGroups)' \
  --region ap-south-1)

echo "   Security groups: $SG_COUNT"
```

---

## Best Practices

1. **Always Backup Before Apply**
   - Pre-apply backups catch most issues
   - Minimal overhead (1-2 seconds)

2. **Test Rollback Regularly**
   - Quarterly rollback drills on dev
   - Verify backup/restore process works

3. **Document Change History**
   - Git commits with detailed messages
   - AWS CloudTrail for resource changes

4. **Use State Locking**
   - Prevents concurrent applies
   - DynamoDB lock already configured

5. **Monitor State File Size**
   - Large state files indicate bloat
   - Consider splitting state (advanced)

6. **Keep Backups** 
   - Local copies in git (encrypted)
   - S3 versioning as backup
   - 30-day retention minimum

7. **Plan Before Apply**
   - Always review `terraform plan` output
   - Catch destructive changes early

---

## Tools & Commands Reference

### List Backup Files

```bash
aws s3 ls s3://terraform-state-1768505102/dev/ | grep .tfstate
```

### Download State Backup

```bash
aws s3 cp s3://terraform-state-1768505102/prod/terraform.tfstate ./prod-current.tfstate
```

### Compare State Files

```bash
# Show diff between two states
diff <(jq -S '.resources' terraform-prod-20260117.tfstate) \
     <(jq -S '.resources' terraform-prod-20260118.tfstate)
```

### Verify State Lock Status

```bash
aws dynamodb get-item \
  --table-name terraform-locks \
  --key '{"LockID": {"S": "terraform-state-1768505102/prod/terraform.tfstate"}}'
```

### Force Unlock (Emergency Only)

```bash
aws dynamodb delete-item \
  --table-name terraform-locks \
  --key '{"LockID": {"S": "terraform-state-1768505102/prod/terraform.tfstate"}}'
```

---

## Conclusion

This project benefits most from **Terraform State Rollback** approach because:

1. ✅ Multi-resource state (VPC, EC2, Security Groups, IAM, Secrets)
2. ✅ Centralized S3 backend (easy versioning)
3. ✅ Separate environments (can rollback individually)
4. ✅ Clear state file history (git commits)
5. ✅ Minimal downtime (state-based reconciliation)

**Next Steps:**
- Enable S3 versioning (5 minutes)
- Create rollback scripts (1 hour)
- Add Jenkins stages (2 hours)
- Test on dev (1 hour)
- Document procedures (1 hour)

**Total Implementation Time:** 5 hours
**Recommended Timeline:** 2-4 weeks (phased approach)
