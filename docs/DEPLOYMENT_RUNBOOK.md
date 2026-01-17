# DEPLOYMENT & OPERATIONAL RUNBOOK

## Overview

This runbook provides step-by-step procedures for:
- Pre-deployment validation
- Executing Terraform deployments (plan/apply/destroy)
- Post-deployment verification
- Troubleshooting common issues
- Emergency rollback procedures
- Production-specific controls

---

## PART 1: PRE-DEPLOYMENT CHECKLIST

### Prerequisites

Before triggering any Jenkins deployment, verify:

```bash
# 1. Check Git status (ensure local changes are committed)
git status

# 2. Verify no uncommitted secrets in working directory
git diff --name-only | xargs grep -l "secret\|password\|key" || echo "✓ No secrets in diff"

# 3. Verify AWS credentials are NOT hardcoded
grep -r "AWS_ACCESS_KEY\|AKIA" . --exclude-dir=.git --exclude=*.tfstate || echo "✓ No hardcoded credentials found"

# 4. Check Terraform files for syntax errors
terraform -chdir=env/dev validate
terraform -chdir=env/stage validate
terraform -chdir=env/prod validate

# 5. Verify Secrets Manager secrets exist
echo "=== DEV SECRET ==="
aws secretsmanager get-secret-value --secret-id dev/app-config --region ap-south-1 --query SecretString --output text | jq .

echo "=== STAGE SECRET ==="
aws secretsmanager get-secret-value --secret-id stage/app-config --region ap-south-1 --query SecretString --output text | jq .

echo "=== PROD SECRET ==="
aws secretsmanager get-secret-value --secret-id prod/app-config --region ap-south-1 --query SecretString --output text | jq .
```

### Expected Output

✅ All validation commands succeed without errors
✅ No credentials found in code
✅ Secrets exist in Secrets Manager
✅ Terraform files pass syntax validation

---

## PART 2: DEPLOYING TO DEV

### Step 1: Log into Jenkins

1. Open Jenkins UI: `https://your-jenkins-url/`
2. Navigate to: **Terraform Deployment Pipeline**
3. Click: **Build with Parameters**

### Step 2: Select Parameters

```
ENVIRONMENT: dev
ACTION: plan
AUTO_APPROVE: false (leave unchecked)
```

### Step 3: Execute Plan

1. Click **Build**
2. Monitor build logs in real-time
3. Wait for **Plan Complete** message

### Step 4: Review Plan Output

Jenkins will show:
```
Plan: X to add, Y to change, Z to destroy
```

**If you see plan errors:**
- Check Terraform syntax: `terraform -chdir=env/dev validate`
- Check Secrets Manager secret: `aws secretsmanager get-secret-value --secret-id dev/app-config`
- Check backend bucket exists: `aws s3 ls | grep terraform-state-dev`

### Step 5: Execute Apply

1. Trigger new build with same **ENVIRONMENT: dev**
2. Change **ACTION: apply**
3. Click **Build**
4. When prompted for approval: Click **APPROVE & APPLY**
5. Wait for **Apply Complete** message

### Step 6: Verify Deployment

```bash
# Get deployment outputs
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=dev" \
  --region ap-south-1 \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,PrivateIpAddress,PublicIpAddress]' \
  --output table

# SSH into instance
ssh -i /path/to/keypair.pem ubuntu@<PUBLIC_IP>

# Check Apache is running
sudo systemctl status apache2

# View health page
curl http://<PUBLIC_IP>
```

**Expected Output:**
```
You are in: DEV
Environment: dev
Hostname: ip-10-0-x-x.ap-south-1.compute.internal
IP Address: 10.0.x.x
Instance ID: i-xxxxxxxxx
Availability Zone: ap-south-1a
```

---

## PART 3: DEPLOYING TO STAGE

### Step 1: Plan Stage Deployment

```
ENVIRONMENT: stage
ACTION: plan
AUTO_APPROVE: false
```

### Step 2: Review Plan

Stage is larger than dev (2 t3.small instances vs 1 t3.micro), so expect:
```
Plan: ~X additional resources
```

### Step 3: Apply with Approval

```
ENVIRONMENT: stage
ACTION: apply
AUTO_APPROVE: false
```

**Approval timeout: 30 minutes**
- Approval can be given by: Any Jenkins user (not prod-restricted)

### Step 4: Verify Stage Deployment

```bash
# Check both instances
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=stage" \
  --region ap-south-1 \
  --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress]' \
  --output table

# Load balancer test (if ALB configured)
curl http://<STAGE_LB_URL>/health
curl http://<STAGE_INSTANCE_1>/
curl http://<STAGE_INSTANCE_2>/
```

---

## PART 4: DEPLOYING TO PRODUCTION (RESTRICTED)

### Prerequisites

Production deployments have EXTRA controls:

1. **Approval Window:** 60 minutes (not 30)
2. **Approvers:** Only `devops-lead` or `platform-engineer` roles
3. **Destroy Blocked:** DESTROY action is forbidden for prod
4. **Rollback:** Requires manual intervention from senior engineers

### Procedure: Prod Plan

```
ENVIRONMENT: prod
ACTION: plan
AUTO_APPROVE: false
```

**This will:**
- Validate prod configuration (t3.small, 2 instances, 10.2.0.0/16 CIDR)
- Generate plan artifact
- Save to S3 backend at: `terraform-state-prod/prod/terraform.tfstate`

### Procedure: Prod Apply

```
ENVIRONMENT: prod
ACTION: apply
AUTO_APPROVE: false
```

**Approval:**
- Required approvers: `devops-lead`, `platform-engineer`
- Timeout: 60 minutes
- Input prompt appears in Jenkins build log

**Jenkins will:**
1. Check parameter validation (blocks prod+destroy)
2. Fetch prod secrets from Secrets Manager
3. Lock state file via DynamoDB
4. Execute `terraform apply`
5. Tag resources with prod metadata
6. Store outputs securely in S3

### Verification: Prod Deployment

```bash
# Check production instances
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=prod" \
  --region ap-south-1 \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress,Tags[?Key==`AppVersion`].Value|[0]]' \
  --output table

# Verify instance tags include secrets
aws ec2 describe-tags \
  --filters "Name=resource-type,Values=instance" \
           "Name=key,Values=AppName,AppVersion,ContactEmail" \
  --region ap-south-1 \
  --query 'Tags[].[ResourceId,Key,Value]' \
  --output table

# Verify security groups are restrictive
aws ec2 describe-security-groups \
  --filters "Name=tag:Environment,Values=prod" \
  --region ap-south-1 \
  --query 'SecurityGroups[].[GroupId,GroupName,IpPermissions[].FromPort]' \
  --output table
```

**Expected:**
- 2 t3.small instances running
- VPC CIDR: 10.2.0.0/16
- All instances tagged with app metadata from Secrets Manager
- Security groups only allow SSH (22), HTTP (80), HTTPS (443)

---

## PART 5: DESTROYING INFRASTRUCTURE (CAUTION ⚠️)

### Dev/Stage Destruction

```
ENVIRONMENT: dev  (or stage)
ACTION: destroy
AUTO_APPROVE: false
```

**Jenkins will:**
1. Prompt for 15-minute confirmation input
2. Display all resources that will be deleted
3. Execute `terraform destroy -auto-approve`
4. Remove state file from S3

### Production Destruction (BLOCKED)

```
ENVIRONMENT: prod
ACTION: destroy
```

**Jenkins will:**
❌ **Immediately fail with error:**
```
❌ DESTROY NOT PERMITTED ON PRODUCTION

To avoid accidental deletion of production infrastructure,
DESTROY operations are strictly forbidden on the 'prod' environment.

If you must delete production infrastructure:
1. Contact the DevOps lead for manual intervention
2. Follow the Change Control process
3. Ensure backups are in place
```

**Why?** Production destroy is a rare, high-risk operation that requires:
- Senior approval
- Change board review
- Backup verification
- Post-mortem documentation

---

## PART 6: EMERGENCY ROLLBACK

### If Deployment Fails (Before Apply)

**No infrastructure was created, safe to retry.**

```bash
# 1. Review build logs for errors
# 2. Fix the issue in code
# 3. Commit and push to Git
# 4. Re-run Jenkins build
```

### If Deployment Partially Succeeds

**Some resources were created, some failed.**

```bash
# 1. Check CloudFormation/Terraform state
terraform -chdir=env/ENVIRONMENT show

# 2. Identify which resources succeeded
aws ec2 describe-instances --filters "Name=tag:Environment,Values=ENVIRONMENT"
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=ENVIRONMENT"

# 3. Two options:
#    A. Fix and re-apply (recommended)
#    B. Destroy and restart
```

**Option A: Fix and Re-apply**
```bash
# Fix the issue in code
git commit -am "Fix: ..."
git push origin main

# Re-run apply (will update existing resources)
# Jenkins: ACTION=apply, ENVIRONMENT=<env>
```

**Option B: Destroy and Restart**
```bash
# For dev/stage only (prod requires manual intervention)
# Jenkins: ACTION=destroy, ENVIRONMENT=<env>

# Once destroyed, re-run apply
```

### If Production Deploy Succeeds but Needs Rollback

**Production rollback is manual - no one-click undo.**

1. **Immediate Action:** Isolate impacted resources
   ```bash
   # Put instances in maintenance mode
   aws ec2 reboot-instances --instance-ids i-xxx --region ap-south-1
   ```

2. **Investigation:** Determine root cause
   ```bash
   # Check CloudTrail for API calls
   aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=prod-vpc
   
   # Check application logs
   sudo tail -f /var/log/apache2/error.log
   ```

3. **Recovery Options:**
   - **A. Code Fix + Reapply:** Issue was in Terraform, push fix and reapply
   - **B. Manual Resource Change:** If IaC rollback takes too long, manually fix in console, then update Terraform to match
   - **C. Infrastructure Restore:** If S3 backend was corrupted, restore from backup bucket
   - **D. Full Rebuild:** As last resort, destroy and reapply (rare)

4. **Post-Mortem:** Document what went wrong
   ```bash
   # Create incident post-mortem
   cat > POST_MORTEM.md <<EOF
   Date: $(date)
   Environment: prod
   Issue: 
   Root Cause:
   Impact:
   Resolution:
   Lessons Learned:
   Prevention:
   EOF
   ```

---

## PART 7: CHECKING DEPLOYMENT LOGS

### View Jenkins Build Logs

1. Open Jenkins UI
2. Navigate to build #N
3. Click **Console Output**
4. Search for:

```
✓ Parameter Validation passed
✓ Pre-Validation passed
✓ Terraform Init completed
✓ Terraform Plan completed
✓ Terraform Apply completed
```

### View Terraform Logs in Detail

```bash
# If you have local Terraform:
cd env/dev
terraform apply -input=false -auto-approve

# Or fetch from Jenkins workspace
# Jenkins > Manage Jenkins > System Log
```

### View AWS CloudTrail for Terraform Actions

```bash
# Find all Terraform API calls in the last hour
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=ec2.amazonaws.com \
  --start-time $(date -d '1 hour ago' --iso-8601=seconds) \
  --region ap-south-1 \
  --output table | head -50
```

---

## PART 8: SECURITY VERIFICATION

### After Each Deployment

```bash
# 1. Verify no hardcoded credentials in state
aws s3 cp s3://terraform-state-dev/dev/terraform.tfstate - | grep -i "password\|secret\|key" || echo "✓ No secrets in state"

# 2. Verify IAM role is attached to EC2
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=dev" \
  --region ap-south-1 \
  --query 'Reservations[].Instances[].IamInstanceProfile' \
  --output table

# 3. Verify EC2 can access Secrets Manager
INSTANCE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=dev" \
  --region ap-south-1 \
  --query 'Reservations[].Instances[].PublicIpAddress' \
  --output text | head -1)

ssh -i /path/to/key.pem ubuntu@$INSTANCE_IP <<EOF
  # Inside EC2
  aws secretsmanager get-secret-value --secret-id dev/app-config --region ap-south-1 --query SecretString --output text | jq .
EOF

# 4. Verify no S3 public access
aws s3api get-bucket-acl --bucket terraform-state-dev | grep PublicRead || echo "✓ S3 bucket not publicly accessible"

# 5. Verify DynamoDB locking is working
aws dynamodb scan --table-name terraform-locks --region ap-south-1
```

---

## PART 9: COMMONLY ASKED QUESTIONS

### Q: Can I deploy to prod without approval?
**A:** No. Prod deployments require senior approval and have a 60-minute timeout.

### Q: Can I destroy production infrastructure?
**A:** No. Jenkins will block DESTROY for prod. If you must delete prod:
1. Contact the DevOps lead
2. Follow change control process
3. Get manual approval

### Q: How do I update secrets?
**A:** See [SECRETS_MANAGER_SETUP.md](SECRETS_MANAGER_SETUP.md#rotating-secrets)
```bash
aws secretsmanager update-secret --secret-id dev/app-config --secret-string '{...}'
terraform apply -refresh-only
```

### Q: What if state file is locked?
**A:** Check DynamoDB:
```bash
aws dynamodb scan --table-name terraform-locks --region ap-south-1
# If stuck, you can manually delete the lock, but this is rare
```

### Q: How do I rollback a failed apply?
**A:** Depends on failure type (see PART 6: Emergency Rollback)

### Q: Can I manually edit resources in AWS Console?
**A:** Avoid it. If you must:
1. Make the change
2. Update Terraform code to match
3. Run `terraform apply -refresh-only` to sync state

---

## PART 10: MONITORING & ALERTS

### Post-Deployment Monitoring

```bash
# 1. Monitor EC2 instances
watch -n 5 'aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=dev" \
  --region ap-south-1 \
  --query "Reservations[].Instances[].[InstanceId,State.Name,InstanceType,PublicIpAddress]" \
  --output table'

# 2. Monitor CloudWatch logs
aws logs tail /aws/ec2/dev-web-server --follow

# 3. Monitor security group activity
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=sg-xxxxxxx" \
  --region ap-south-1

# 4. Monitor S3 access logs
aws s3api get-bucket-logging \
  --bucket terraform-state-dev
```

### Set Up Alarms (Optional)

```bash
# CPU usage alarm for high resource consumption
aws cloudwatch put-metric-alarm \
  --alarm-name dev-high-cpu \
  --alarm-description "Alert if CPU > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold
```

---

## QUICK REFERENCE

| Task | Command | Jenkins Parameters |
|------|---------|-------------------|
| Plan Dev | `terraform plan` | `ENV=dev, ACTION=plan` |
| Apply Dev | `terraform apply` | `ENV=dev, ACTION=apply` |
| Destroy Dev | `terraform destroy` | `ENV=dev, ACTION=destroy` |
| Plan Prod | (same) | `ENV=prod, ACTION=plan` |
| Apply Prod | (with approval) | `ENV=prod, ACTION=apply` |
| Destroy Prod | ❌ BLOCKED | N/A |

---

## SUMMARY

✅ **Before deploying:** Check all prerequisites and validation steps
✅ **Dev/Stage:** Can be freely deployed and destroyed
✅ **Prod:** Requires senior approval, destroy is blocked
✅ **Secrets:** Fetched from Secrets Manager, never hardcoded
✅ **State:** Stored in S3 + DynamoDB with locking
✅ **Rollback:** For prod, contact senior engineer

**Questions?** See Jenkins logs or contact DevOps team.

