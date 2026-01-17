# Quick Reference Guide

## 🚀 Quick Start

### 1. Setup AWS Infrastructure (First Time Only)
```bash
# Read the complete guide
cat docs/BACKEND_SETUP.md

# Execute the commands to create:
# - S3 buckets (terraform-state-dev/stage/prod)
# - DynamoDB table (terraform-locks)
# - IAM roles/users for Jenkins
# - Secrets Manager secrets for each environment
```

### 2. Configure Jenkins
```bash
# Read the complete guide
cat docs/JENKINS_CONFIGURATION.md

# Option A: If Jenkins is on EC2
# - Attach IAM role to instance
# - Restart Jenkins

# Option B: If Jenkins is on bare metal
# - Create ~/.aws/credentials file
# - Add access key/secret for Jenkins IAM user
```

### 3. Deploy to Dev
```bash
# In Jenkins UI:
# - Environment: dev
# - Action: PLAN
# - Click Build

# Review plan output, then:
# - Environment: dev
# - Action: APPLY
# - Click Build and Approve
```

---

## 📋 File Reference

| File | Purpose | Status |
|------|---------|--------|
| `ARCHITECTURE_ANALYSIS.md` | Detailed analysis of changes | 📖 Read first |
| `IMPLEMENTATION_SUMMARY.md` | What was changed and why | 📖 Review |
| `docs/BACKEND_SETUP.md` | AWS infrastructure setup | 🔧 Execute |
| `docs/JENKINS_CONFIGURATION.md` | Jenkins security setup | 🔧 Execute |
| `docs/SECURITY_BEST_PRACTICES.md` | Security guidelines | 📖 Reference |
| `Jenkinsfile` | Updated pipeline (NO credentials) | ✅ Ready |
| `env/dev/` | Development Terraform | ✅ Ready |
| `env/stage/` | Staging Terraform | ✅ Ready |
| `env/prod/` | Production Terraform | ✅ Ready |
| `modules/iam/instance_role/` | EC2 IAM roles | ✅ Ready |
| `scripts/install_apache2.sh` | Environment-aware setup | ✅ Ready |
| `.gitignore` | Prevents credential commits | ✅ Ready |

---

## 🔐 Security Checklist

Before first deployment:

- [ ] Read docs/SECURITY_BEST_PRACTICES.md
- [ ] Create S3 buckets with encryption/versioning
- [ ] Create DynamoDB table for state locking
- [ ] Create IAM role/user for Jenkins
- [ ] Configure Jenkins with IAM role or credentials file
- [ ] Create Secrets Manager secrets (dev/stage/prod)
- [ ] Verify no credentials in git history: `git log --all -S "AKIA" --oneline`
- [ ] Test Terraform plan for each environment
- [ ] Verify approval workflow for prod

---

## 📊 Environment Comparison

| Aspect | Dev | Stage | Prod |
|--------|-----|-------|------|
| **VPC CIDR** | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| **Instance Type** | t3.micro | t3.small | t3.small |
| **Instance Count** | 1 | 2 | 2 |
| **Approval Required** | No | Yes | Yes (Senior) |
| **Approval Timeout** | 30 min | 30 min | 60 min |
| **Can Destroy** | ✓ Yes | ✓ Yes | ✗ No |
| **State Bucket** | terraform-state-dev | terraform-state-stage | terraform-state-prod |

---

## 🐛 Common Issues & Solutions

### "Unable to locate credentials"
```bash
# Check if Jenkins has IAM role or credentials file
aws sts get-caller-identity

# If fails, follow docs/JENKINS_CONFIGURATION.md
```

### "State lock timeout"
```bash
# Check DynamoDB table exists
aws dynamodb describe-table --table-name terraform-locks

# If stale lock, remove it (use with caution)
aws dynamodb scan --table-name terraform-locks
```

### "Access Denied" to S3
```bash
# Verify IAM policy is attached
aws iam list-attached-role-policies --role-name jenkins-terraform-role

# Verify bucket exists
aws s3 ls | grep terraform-state
```

### "Apache page doesn't show environment"
```bash
# Check user_data script was executed
# SSH to instance and check:
tail /var/log/cloud-init-output.log

# View Apache page
curl http://INSTANCE_IP/
```

---

## 🔄 Deployment Workflow

```
1. Developer pushes to GitHub
   ↓
2. Jenkins triggered (manual or webhook)
   ↓
3. Select ENVIRONMENT (dev/stage/prod)
   ↓
4. Select ACTION (PLAN/APPLY/DESTROY)
   ↓
5. Terraform Plan runs
   ↓
6. Review plan output in Jenkins
   ↓
7. Click APPROVE (if required for environment)
   ↓
8. Terraform Apply runs
   ↓
9. Infrastructure created/updated
   ↓
10. Outputs generated (IPs, ARNs, etc.)
   ↓
11. Access Apache on public IP
```

---

## 📈 Scaling Beyond This Setup

### Add New Environment
```bash
# Copy env/prod/ to env/staging-2/
cp -r env/prod/ env/staging-2/

# Update backend.tf with new bucket
# Update terraform.tfvars with new CIDR
# Add 'staging-2' to Jenkinsfile choices
# Create S3 bucket and Secrets Manager secret
```

### Separate Modules Repo
```bash
# Create new repository for modules/
# Push modules/ to new repo
# Reference via Git source in terraform

module "vpc" {
  source = "git::https://github.com/org/terraform-modules.git//vpc?ref=v1.0.0"
}
```

### Multi-Account Setup
```bash
# Create separate AWS account for prod
# Create cross-account IAM role
# Update Jenkins IAM policy to assume role
# Update terraform block to assume prod account role
```

---

## 🎯 Success Criteria

✓ Terraform plans successfully for all environments  
✓ State files stored encrypted in S3  
✓ State locks work without timeouts  
✓ Jenkins uses IAM role (not hardcoded credentials)  
✓ Each environment has unique VPC CIDR  
✓ Apache page shows correct environment  
✓ Prod approval workflow requires senior sign-off  
✓ Terraform destroy works as expected  
✓ No credentials in Git history  
✓ All documentation reviewed by team  

---

## 💬 Questions?

1. **Architecture question?**  
   → Read: `ARCHITECTURE_ANALYSIS.md`

2. **How to set up AWS resources?**  
   → Read: `docs/BACKEND_SETUP.md`

3. **How to configure Jenkins?**  
   → Read: `docs/JENKINS_CONFIGURATION.md`

4. **Security concern?**  
   → Read: `docs/SECURITY_BEST_PRACTICES.md`

5. **What changed in Terraform?**  
   → Read: `IMPLEMENTATION_SUMMARY.md`

6. **Need detailed explanation?**  
   → Read: Inline comments in modified `.tf` files

---

## 📞 Support Commands

```bash
# Verify AWS setup
aws s3 ls | grep terraform-state
aws dynamodb list-tables | grep terraform-locks
aws iam get-role --role-name jenkins-terraform-role

# Verify Terraform
cd env/dev && terraform init && terraform validate
cd env/stage && terraform init && terraform validate
cd env/prod && terraform init && terraform validate

# Check Git for secrets
git log --all -S "AKIA" --oneline
git log --all -S "secret" --oneline

# Verify Jenkins connectivity
aws sts get-caller-identity
aws secretsmanager get-secret-value --secret-id dev/terraform-env-vars
```

---

## 🎓 Learning Resources

- [Terraform Best Practices](https://www.terraform.io/docs/language/index.html)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Jenkins Pipeline Documentation](https://jenkins.io/doc/book/pipeline/)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [Terraform State Management](https://www.terraform.io/docs/language/state/index.html)

---

**Last Updated:** January 17, 2026  
**Status:** ✅ Production Ready (85%)  
**Next Step:** Execute docs/BACKEND_SETUP.md

