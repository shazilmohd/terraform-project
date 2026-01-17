# PRE-DEPLOYMENT VERIFICATION CHECKLIST

## ⚠️ CRITICAL: Run This Before First Deployment

This checklist ensures all security fixes are properly implemented before deploying to any environment.

---

## STEP 1: Verify Jenkinsfile Security (⏱️ 5 mins)

```bash
# 1.1 Check NO hardcoded credentials
grep -i "credentials\|AWS_ACCESS\|AWS_SECRET" Jenkinsfile && echo "❌ FOUND HARDCODED CREDENTIALS" || echo "✅ No hardcoded credentials"

# Expected: ✅ No hardcoded credentials

# 1.2 Check Parameter Validation stage exists
grep -c "Parameter Validation" Jenkinsfile && echo "✅ Parameter validation stage exists" || echo "❌ Missing validation stage"

# Expected: ✅ Parameter validation stage exists

# 1.3 Check Prod destroy is blocked
grep -c "DESTROY NOT PERMITTED ON PRODUCTION" Jenkinsfile && echo "✅ Prod destroy protection exists" || echo "❌ Missing destroy protection"

# Expected: ✅ Prod destroy protection exists

# 1.4 Check Dynamic backend config
grep -c "backend-config=" Jenkinsfile && echo "✅ Dynamic backend config found" || echo "❌ Missing dynamic backend"

# Expected: ✅ Dynamic backend config found
```

---

## STEP 2: Verify Terraform Files Security (⏱️ 5 mins)

```bash
# 2.1 Check backend.tf files are minimal (no hardcoded bucket names)
for file in env/*/backend.tf; do
  if grep -q "bucket.*=.*\"terraform-state-" "$file"; then
    echo "❌ $file has hardcoded bucket name"
  else
    echo "✅ $file is properly dynamic"
  fi
done

# Expected: All three should show ✅

# 2.2 Check all environments have secrets consumption
for file in env/*/main.tf; do
  if grep -q "local.app_name\|local.app_version\|local.contact_email" "$file"; then
    echo "✅ $file consumes secrets"
  else
    echo "❌ $file doesn't consume secrets"
  fi
done

# Expected: All three should show ✅

# 2.3 Check prod environment exists
[ -f env/prod/main.tf ] && echo "✅ Prod environment exists" || echo "❌ Missing prod environment"

# Expected: ✅ Prod environment exists

# 2.4 Check unique VPC CIDRs per environment
echo "Dev CIDR:"
grep "vpc_cidr" env/dev/terraform.tfvars
echo "Stage CIDR:"
grep "vpc_cidr" env/stage/terraform.tfvars
echo "Prod CIDR:"
grep "vpc_cidr" env/prod/terraform.tfvars

# Expected:
# Dev: 10.0.0.0/16
# Stage: 10.1.0.0/16
# Prod: 10.2.0.0/16
```

---

## STEP 3: Verify IAM Module (⏱️ 3 mins)

```bash
# 3.1 Check IAM module exists
[ -f modules/iam/instance_role/main.tf ] && echo "✅ IAM module exists" || echo "❌ Missing IAM module"

# 3.2 Check IAM module has required policies
grep -c "secretsmanager:GetSecretValue\|logs:PutLogEvents" modules/iam/instance_role/main.tf
if [ $? -eq 0 ]; then
  echo "✅ IAM module has required policies"
else
  echo "❌ IAM module missing policies"
fi

# 3.3 Check IAM module is used in all environments
for file in env/*/main.tf; do
  if grep -q "module.ec2_instance_role" "$file"; then
    echo "✅ $file uses IAM module"
  else
    echo "❌ $file doesn't use IAM module"
  fi
done

# Expected: All three should show ✅
```

---

## STEP 4: Verify Git Security (⏱️ 5 mins)

```bash
# 4.1 Check .gitignore exists and is comprehensive
if [ -f .gitignore ]; then
  line_count=$(wc -l < .gitignore)
  if [ $line_count -gt 100 ]; then
    echo "✅ .gitignore is comprehensive ($line_count lines)"
  else
    echo "⚠️  .gitignore might be incomplete ($line_count lines)"
  fi
else
  echo "❌ .gitignore missing"
fi

# Expected: ✅ .gitignore is comprehensive (120+ lines)

# 4.2 Check no secrets in Git history
git log --all --source --grep="secret\|password\|key" --oneline | head -5
if [ $? -eq 0 ]; then
  echo "⚠️  Check above for any secret-related commits"
else
  echo "✅ No secret references found in recent commits"
fi

# 4.3 Check .terraform directory is in .gitignore
grep -q "\.terraform/" .gitignore && echo "✅ .terraform/ is in .gitignore" || echo "❌ .terraform/ not in .gitignore"

# 4.4 Check *.tfstate is in .gitignore
grep -q "\*\.tfstate" .gitignore && echo "✅ *.tfstate is in .gitignore" || echo "❌ *.tfstate not in .gitignore"

# Expected: All should show ✅
```

---

## STEP 5: Verify Documentation (⏱️ 3 mins)

```bash
# 5.1 Check all required documentation exists
docs_files=(
  "docs/BACKEND_SETUP.md"
  "docs/JENKINS_CONFIGURATION.md"
  "docs/SECRETS_MANAGER_SETUP.md"
  "docs/DEPLOYMENT_RUNBOOK.md"
  "docs/SECURITY_REFACTOR_CHECKLIST.md"
)

for doc in "${docs_files[@]}"; do
  if [ -f "$doc" ]; then
    echo "✅ $doc exists"
  else
    echo "❌ $doc missing"
  fi
done

# Expected: All should show ✅

# 5.2 Check root-level summary exists
[ -f REFACTOR_COMPLETION_SUMMARY.md ] && echo "✅ REFACTOR_COMPLETION_SUMMARY.md exists" || echo "❌ Missing summary"

# Expected: ✅ REFACTOR_COMPLETION_SUMMARY.md exists
```

---

## STEP 6: Terraform Validation (⏱️ 10 mins)

```bash
# 6.1 Validate each environment
for env in dev stage prod; do
  echo "=== Validating $env environment ==="
  cd env/$env
  terraform init -backend=false  # Don't need backend for validation
  terraform validate
  if [ $? -eq 0 ]; then
    echo "✅ env/$env passes validation"
  else
    echo "❌ env/$env has syntax errors"
  fi
  cd ../..
done

# Expected: All three should show ✅

# 6.2 Check variable definitions
for env in dev stage prod; do
  if [ -f "env/$env/variables.tf" ]; then
    echo "✅ env/$env/variables.tf exists"
  else
    echo "❌ env/$env/variables.tf missing"
  fi
done

# Expected: All should show ✅

# 6.3 Check terraform.tfvars have non-sensitive values only
for env in dev stage prod; do
  if grep -i "password\|secret\|key\|token" "env/$env/terraform.tfvars"; then
    echo "❌ env/$env/terraform.tfvars has sensitive values"
  else
    echo "✅ env/$env/terraform.tfvars is clean"
  fi
done

# Expected: All should show ✅
```

---

## STEP 7: AWS Account Readiness (⏱️ 15 mins)

```bash
# 7.1 Check AWS credentials work
aws sts get-caller-identity
if [ $? -eq 0 ]; then
  echo "✅ AWS credentials are valid"
else
  echo "❌ AWS credentials failed - check aws configure"
  exit 1
fi

# 7.2 Check region is correct
AWS_REGION=$(aws configure get region)
if [ "$AWS_REGION" = "ap-south-1" ]; then
  echo "✅ AWS region is set to ap-south-1"
else
  echo "⚠️  AWS region is $AWS_REGION (expected ap-south-1)"
fi

# 7.3 Check S3 buckets don't exist yet (first deployment)
for bucket in terraform-state-dev terraform-state-stage terraform-state-prod; do
  if aws s3 ls "s3://$bucket" 2>/dev/null; then
    echo "⚠️  S3 bucket $bucket already exists (might be from previous deployment)"
  else
    echo "✅ S3 bucket $bucket doesn't exist (ready to create)"
  fi
done

# Expected: Either ✅ (new deployment) or ⚠️ (re-deployment, check if you want to reuse)

# 7.4 Check DynamoDB table doesn't exist
if aws dynamodb describe-table --table-name terraform-locks --region ap-south-1 2>/dev/null; then
  echo "ℹ️  DynamoDB table terraform-locks already exists"
else
  echo "✅ DynamoDB table needs to be created"
fi

# 7.5 Check IAM permissions (optional but recommended)
echo "Your AWS user/role can perform:"
aws iam get-user 2>/dev/null || aws sts get-caller-identity --query Arn --output text
```

---

## STEP 8: Jenkins Readiness (⏱️ 10 mins)

```bash
# 8.1 Check Jenkins has Terraform installed
ssh ec2-user@<JENKINS_IP> "terraform version" 2>/dev/null || echo "Check Jenkins has Terraform installed"

# 8.2 Check Jenkins has AWS CLI installed
ssh ec2-user@<JENKINS_IP> "aws --version" 2>/dev/null || echo "Check Jenkins has AWS CLI installed"

# 8.3 Check Jenkins can call AWS API
ssh ec2-user@<JENKINS_IP> "aws sts get-caller-identity" 2>/dev/null && \
  echo "✅ Jenkins can authenticate to AWS" || \
  echo "❌ Jenkins cannot authenticate to AWS - check IAM role attachment"

# 8.4 Check Jenkins workspace exists
ssh ec2-user@<JENKINS_IP> "ls -la /var/lib/jenkins/workspace" 2>/dev/null && \
  echo "✅ Jenkins workspace exists" || \
  echo "⚠️  Check Jenkins workspace directory"
```

---

## STEP 9: Security Scan (⏱️ 10 mins)

```bash
# 9.1 Scan entire repo for hardcoded credentials
echo "Scanning for hardcoded credentials..."
if grep -r "AKIA\|aws_access_key\|aws_secret_key\|AWS_SECRET" . \
  --exclude-dir=.git \
  --exclude-dir=.terraform \
  --exclude-dir=node_modules \
  --exclude="*.tfstate" \
  --exclude-dir=docs 2>/dev/null | grep -v "secretsmanager_secret_name\|secret_name"; then
  echo "❌ FOUND POTENTIAL CREDENTIALS - REVIEW ABOVE"
  exit 1
else
  echo "✅ No hardcoded credentials found"
fi

# 9.2 Check for default passwords
if grep -r "password.*123\|admin.*password\|default.*pass" . --exclude-dir=.git --exclude-dir=docs 2>/dev/null; then
  echo "⚠️  Found potential default passwords - review above"
else
  echo "✅ No obvious default passwords"
fi

# 9.3 Check for exposed PEM files
if find . -name "*.pem" -o -name "*.key" -o -name "*.ppk" 2>/dev/null | grep -v ".gitignore"; then
  echo "❌ FOUND KEY FILES - DELETE IMMEDIATELY"
  exit 1
else
  echo "✅ No key files in repository"
fi
```

---

## FINAL SUMMARY

```bash
# Count all ✅ marks to see overall readiness
echo ""
echo "=========================================="
echo "FINAL VERIFICATION SUMMARY"
echo "=========================================="

# Run all checks and count successes
checks_passed=$(
  {
    grep -c "Parameter Validation" Jenkinsfile 2>/dev/null || true
    grep -c "DESTROY NOT PERMITTED" Jenkinsfile 2>/dev/null || true
    [ -f env/prod/main.tf ] && echo "1" || true
    [ -f modules/iam/instance_role/main.tf ] && echo "1" || true
    grep -c "\.terraform/" .gitignore 2>/dev/null || true
    [ -f docs/BACKEND_SETUP.md ] && echo "1" || true
    [ -f REFACTOR_COMPLETION_SUMMARY.md ] && echo "1" || true
  } | wc -l
)

if [ $checks_passed -ge 7 ]; then
  echo "✅ READY FOR DEPLOYMENT"
  echo ""
  echo "Next steps:"
  echo "1. Follow docs/BACKEND_SETUP.md to create AWS infrastructure"
  echo "2. Follow docs/JENKINS_CONFIGURATION.md to configure Jenkins"
  echo "3. Follow docs/SECRETS_MANAGER_SETUP.md to create secrets"
  echo "4. Follow docs/DEPLOYMENT_RUNBOOK.md to deploy"
else
  echo "⚠️  ISSUES FOUND - Please resolve above before deploying"
  echo ""
  echo "Issues found:"
  echo "- Check Jenkins parameter validation is present"
  echo "- Check prod destroy protection is in place"
  echo "- Check prod environment exists"
  echo "- Check IAM module exists"
  echo "- Check .gitignore has .terraform/"
  echo "- Check documentation files exist"
  exit 1
fi

echo "=========================================="
```

---

## ⚠️ IF CHECKS FAIL

### Common Issues and Solutions

**Issue: "No hardcoded credentials" check fails**
→ Search for the string in Jenkinsfile and remove it
→ Check: `grep -n "credentials\|AWS_KEY" Jenkinsfile`

**Issue: "Parameter Validation stage" missing**
→ Jenkinsfile wasn't updated
→ Re-read the latest Jenkinsfile from the refactor

**Issue: "backend-config" not found**
→ Terraform Init stage wasn't updated
→ Manually add `-backend-config` flags to terraform init

**Issue: "Prod environment" missing**
→ env/prod/ directory wasn't created
→ Create env/prod/ directory and copy files from dev/

**Issue: "IAM module" missing**
→ modules/iam/instance_role/ wasn't created
→ Create the module with EC2 role and policies

**Issue: ".gitignore" incomplete**
→ Add these critical lines:
```
.terraform/
*.tfstate*
*.pem
*.key
.env
```

**Issue: "AWS credentials" check fails**
→ Run: `aws configure` and enter valid credentials
→ Or: Check IAM role is attached to Jenkins

**Issue: "Documentation" files missing**
→ Re-read all document files created
→ Copy them to docs/ directory

---

## 🚀 WHEN READY TO PROCEED

Once all checks pass (✅), proceed with:

1. **Phase 1 (Day 1):** `docs/BACKEND_SETUP.md` - Create AWS resources
2. **Phase 2 (Day 1-2):** `docs/JENKINS_CONFIGURATION.md` - Configure Jenkins
3. **Phase 3 (Day 2-3):** `docs/SECRETS_MANAGER_SETUP.md` - Create secrets
4. **Phase 4 (Day 3):** `docs/DEPLOYMENT_RUNBOOK.md` - Deploy infrastructure

---

**Checklist Version:** 1.0
**Last Updated:** January 17, 2026
**Status:** Ready for use

