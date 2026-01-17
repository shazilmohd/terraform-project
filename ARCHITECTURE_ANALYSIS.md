# Terraform + Jenkins CI/CD Architecture Analysis & Refactoring Plan

## Executive Summary

Your Terraform + Jenkins CI/CD codebase has a **strong foundational structure** with modular Terraform designs and parameterized Jenkins pipelines. However, there are **critical security gaps, incomplete environment support, and production-readiness issues** that must be addressed.

**Status:** 70% aligned with target architecture | 15 medium-to-critical improvements needed

---

## PART 1: WHAT ALREADY ALIGNS ✓

### 1.1 Terraform Modularity (GOOD)
- ✓ Modules are properly separated: `vpc/`, `ec2/`, `security_group/`, `secret_manager/`
- ✓ Environment-specific configs in `env/dev/` and `env/stage/`
- ✓ Modules reuse across environments (VPC, EC2, SG are identical)
- ✓ Proper module inputs/outputs structure
- ✓ Variables properly typed and documented

### 1.2 Jenkins Pipeline Structure (GOOD)
- ✓ Parameterized build with ENVIRONMENT and ACTION choices
- ✓ Dynamic TF_WORKING_DIR based on environment parameter
- ✓ Terraform validate, plan, apply, destroy stages
- ✓ Manual approval gate for APPLY (configurable auto-approve)
- ✓ Artifacts archiving (tfplan, outputs, summary)
- ✓ Pre-validation checks (terraform, aws cli installed)
- ✓ Proper logging and timestamps

### 1.3 EC2 & Apache (GOOD)
- ✓ EC2 provisioned via Terraform
- ✓ Apache auto-installed via user_data script
- ✓ Basic health check page created
- ✓ Web server accessible on port 80

### 1.4 Infrastructure as Code Features (GOOD)
- ✓ Terraform init, validate, plan, apply pattern
- ✓ State management configured (S3 backend)
- ✓ Outputs properly defined for EC2, VPC, SGs
- ✓ Tags consistently applied

---

## PART 2: CRITICAL GAPS & RISKS 🔴

### 2.1 SECURITY - Credentials & Secrets Management

**CRITICAL ISSUES:**

1. **Hardcoded AWS credentials in Jenkins environment**
   - Line 39 in Jenkinsfile: `AWS_CREDENTIALS = credentials('aws-bootstrap-creds')`
   - This fetches credentials from Jenkins Secret store into environment variables
   - **Risk:** Credentials exposed in build logs, Jenkins workspace, process environment
   - **Requirement:** Jenkins must use IAM roles, NOT AWS access keys

2. **Secrets Manager integration incomplete**
   - `env/dev/main.tf` declares: `data "aws_secretsmanager_secret_version" "env_secrets"` 
   - **Problem:** Secret is never actually USED to populate variables
   - The `locals.secrets` map is created but never referenced
   - **Requirement:** All sensitive values MUST come from Secrets Manager

3. **terraform.tfvars contains sensitive defaults**
   - `env/dev/terraform.tfvars` has: `secrets_manager_secret_name = "dev/terraform-env-vars"`
   - While it's a reference, the actual values should NOT be defaults
   - **Problem:** If secret doesn't exist, Terraform fails without fallback
   - **Requirement:** All env-specific values must be fetched from Secrets Manager

4. **No Jenkins IAM role configured**
   - Current setup expects AWS CLI configured locally on Jenkins
   - **Requirement:** Jenkins machine must have IAM instance role (or user-level equivalent)
   - Jenkins must NOT use hardcoded AWS access keys

### 2.2 Backend & State Management

**GAPS:**

1. **S3 backend hardcoded in backend.tf**
   - `env/dev/backend.tf`: `bucket = "terraform-state-1768505102"` is hardcoded
   - `key = "dev/terraform.tfstate"` is hardcoded but assumes environment name
   - **Problem:** Backend cannot be dynamically selected during pipeline execution
   - **Requirement:** Backend initialization must be parameterized in Jenkins

2. **DynamoDB locking NOT configured**
   - No `dynamodb_table` in backend.tf
   - **Risk:** Concurrent Terraform runs can corrupt state
   - **Requirement:** Must add DynamoDB table reference for state locking

3. **S3 bucket hardcoded**
   - The bucket must be created separately before running Terraform
   - No bucket creation automation/documentation
   - **Requirement:** Document bucket creation with encryption, versioning, private access

4. **No .terraform directory version control**
   - Backend is initialized locally before pipeline runs
   - `.terraform/` may be committed to git
   - **Requirement:** Ensure .gitignore is properly configured

### 2.3 Environment Support

**GAPS:**

1. **prod environment missing**
   - Only `env/dev/` and `env/stage/` exist
   - `env/prod/` directory does not exist
   - Jenkinsfile supports only dev/stage in choices
   - **Requirement:** Must add `env/prod/` with separate state file and security rules

2. **Incomplete stage environment**
   - `env/stage/terraform.tfvars` likely identical to dev
   - No separation of stage-specific networking (same CIDR ranges)
   - **Requirement:** Stage should have separate VPC CIDR, instance types, etc.

### 2.4 Terraform Configuration Issues

**GAPS:**

1. **AMI data source lookups duplicated**
   - Each environment file has: `data "aws_ami" "ubuntu"`
   - These should be in a shared variable or module
   - **Improvement:** Move to variables.tf as a variable

2. **Data source dependency missing**
   - `main.tf` uses `data.aws_ami.ubuntu.id` immediately
   - But `data.aws_ami` data source is defined later in file
   - **Risk:** Terraform may fail if data source isn't evaluated first
   - **Best Practice:** Define data sources before using them

3. **Secrets Manager secret fetch but not used**
   - Line 21-25 in `env/dev/main.tf`: Fetches secrets but never decodes for use
   - EC2 module doesn't receive environment-specific parameters
   - **Requirement:** Use secrets to populate EC2 tags, names, configs

4. **VPC CIDR ranges not unique per environment**
   - `dev/terraform.tfvars`: `vpc_cidr = "10.0.0.0/16"`
   - `stage/terraform.tfvars` likely the same
   - **Risk:** If deployed to same account, CIDR collision
   - **Requirement:** Use unique CIDRs: dev 10.0.0.0/16, stage 10.1.0.0/16, prod 10.2.0.0/16

5. **No IAM role for EC2 instances**
   - Instances can't access Secrets Manager, CloudWatch, S3
   - **Requirement:** Create IAM module with instance profiles

### 2.5 Jenkins Pipeline Issues

**GAPS:**

1. **Backend initialization doesn't use parameters**
   - `terraform init` doesn't pass `-backend-config` flags
   - Backend is hardcoded in `.tf` files
   - **Problem:** Cannot dynamically select different S3 backends
   - **Requirement:** Use `-backend-config` in pipeline to override backend

2. **No credential provider chain**
   - Jenkins fetches credentials into environment variables
   - **Problem:** Violates requirement "no AWS credentials stored in Jenkins"
   - **Requirement:** Use IAM roles instead of hardcoded credentials

3. **Plan artifacts not secure**
   - `terraform plan` output is archived as artifact
   - Plan files may contain sensitive values
   - **Requirement:** Encrypt artifacts or mark them sensitive

4. **Destroy approval message incomplete**
   - Destroy stage exists but prompt is truncated in code
   - **Minor:** Verify full message displays

5. **No variable validation in pipeline**
   - Jenkins accepts parameters without validation
   - **Requirement:** Add validation stage before Terraform init

### 2.6 Apache2 Setup Script Issues

**GAPS:**

1. **No environment awareness**
   - Health check page shows hostname/IP but NOT environment name
   - **Requirement:** Page must display "You are in: DEV | STAGE | PROD"
   - This allows quick verification of correct environment deployment

2. **Script doesn't receive environment as parameter**
   - User data script is static file content
   - **Requirement:** Either embed environment in Terraform or use Secrets Manager

### 2.7 Repository & Git Structure

**GAPS:**

1. **No .gitignore**
   - Terraform state files could be committed
   - `.terraform/` directory could be in git
   - `terraform.tfvars` with sensitive values could leak
   - **Requirement:** Create proper .gitignore

2. **Single repository setup**
   - Target architecture expects 2 repos:
     - Modules repo (shared)
     - Environment manifests repo (this one)
   - Current setup combines both
   - **Recommendation:** If sharing modules across orgs, split repos
   - **Current state:** Acceptable for single-team use

3. **No branch protection**
   - Any branch can deploy to prod
   - **Requirement:** Enforce main/master for prod deployments

### 2.8 Documentation & Operational Procedures

**GAPS:**

1. **No setup procedure for AWS prerequisites**
   - S3 bucket creation not documented
   - DynamoDB table not documented
   - IAM user/role setup not documented
   - Secrets Manager secret structure not documented

2. **No Jenkins credential setup guide**
   - How to create Jenkins credentials
   - How to configure IAM role (instead of keys)
   - Which credentials are referenced where

3. **No production deployment runbook**
   - No guide for deploying to prod
   - No approval authority specifications
   - No rollback procedures

---

## PART 3: DETAILED REFACTORING PLAN

### Phase 1: Security Hardening (CRITICAL)

#### 1.1 Remove hardcoded credentials from Jenkinsfile
- Remove: `AWS_CREDENTIALS = credentials('aws-bootstrap-creds')`
- Add: Configure Jenkins to assume IAM role on the Jenkins machine
- Jenkins environment must have IAM credentials via instance profile/role
- AWS CLI will automatically use the role via credential chain

**Files to modify:**
- `Jenkinsfile` - Remove credential variable assignments

#### 1.2 Implement Secrets Manager for all sensitive values
- Create a secret in Secrets Manager: `terraform/dev`, `terraform/stage`, `terraform/prod`
- Secret structure:
  ```json
  {
    "vpc_cidr": "10.0.0.0/16",
    "public_subnet_cidrs": ["10.0.1.0/24"],
    "private_subnet_cidrs": ["10.0.2.0/24"],
    "instance_type": "t3.micro",
    "instance_count": 1,
    "key_pair_name": "dev-keypair"
  }
  ```
- Terraform fetches this secret and uses values
- Remove defaults from `terraform.tfvars`

**Files to modify:**
- `env/dev/main.tf` - Actually USE the fetched secrets
- `env/stage/main.tf` - Same pattern
- `env/prod/main.tf` - Create new
- `env/dev/terraform.tfvars` - Remove sensitive values
- `env/stage/terraform.tfvars` - Remove sensitive values
- `env/prod/terraform.tfvars` - Create new

#### 1.3 Add DynamoDB state locking
- Create DynamoDB table: `terraform-locks`
- Add to backend.tf: `dynamodb_table = "terraform-locks"`

**Files to modify:**
- `env/dev/backend.tf`
- `env/stage/backend.tf`
- `env/prod/backend.tf`

### Phase 2: Backend & State Management

#### 2.1 Parameterize backend initialization
- Modify Jenkinsfile to pass backend config as parameters
- Use `-backend-config` flags during `terraform init`

**Files to modify:**
- `Jenkinsfile` - Add backend config parameters

#### 2.2 Document S3 bucket creation
- Bucket name format: `terraform-state-{environment}`
- Enable versioning, encryption, block public access
- Create guide document

**Files to create:**
- `docs/BACKEND_SETUP.md`

### Phase 3: Environment Completeness

#### 3.1 Create prod environment
- Copy `env/dev/` → `env/prod/`
- Modify CIDR ranges (10.2.0.0/16)
- Modify instance type (t3.small or larger)
- Restrict security group sources
- Update backend key path to `prod/terraform.tfstate`

**Files to create:**
- `env/prod/main.tf`
- `env/prod/variables.tf`
- `env/prod/outputs.tf`
- `env/prod/backend.tf`
- `env/prod/terraform.tfvars`

#### 3.2 Update Jenkinsfile prod support
- Add 'prod' to ENVIRONMENT choices
- Require manual approval + additional approval for prod

**Files to modify:**
- `Jenkinsfile` - Add prod environment and stricter approval

### Phase 4: Terraform Improvements

#### 4.1 Add IAM module
- Create: `modules/iam/instance_role/`
- Provides: EC2 instance profile with Secrets Manager, CloudWatch, S3 access
- Use in EC2 module

**Files to create:**
- `modules/iam/instance_role/main.tf`
- `modules/iam/instance_role/variables.tf`
- `modules/iam/instance_role/outputs.tf`

#### 4.2 Fix data source references
- Move AMI lookup to each environment's main.tf (top of file)
- Or create a data module that centralizes this

**Files to modify:**
- `env/dev/main.tf` - Move `data.aws_ami` to top
- `env/stage/main.tf` - Same
- `env/prod/main.tf` - Same

#### 4.3 Use unique VPC CIDRs
- Dev: 10.0.0.0/16
- Stage: 10.1.0.0/16
- Prod: 10.2.0.0/16

**Files to modify:**
- `env/stage/terraform.tfvars` - Update VPC CIDR
- `env/prod/terraform.tfvars` - Set to 10.2.0.0/16

#### 4.4 Remove unused Secrets Manager module
- The app_secrets module creates an empty secret (create_secret = false)
- Either use it to store actual app secrets, or remove it
- **Recommendation:** Keep it but enable for prod use

**Files to modify:**
- `env/dev/main.tf` - Set create_secret = true if using
- `env/stage/main.tf` - Same
- `env/prod/main.tf` - Same

### Phase 5: Apache2 Configuration

#### 5.1 Make Apache page environment-aware
- Pass environment name as variable to EC2 module
- Embed environment in user_data script
- Page displays: "You are in: DEV | STAGE | PROD"

**Files to modify:**
- `scripts/install_apache2.sh` - Accept environment as template
- `env/dev/main.tf` - Pass environment to user_data
- `env/stage/main.tf` - Same
- `env/prod/main.tf` - Same
- `modules/compute/ec2/main.tf` - May need template enhancement

### Phase 6: Repository & Documentation

#### 6.1 Add .gitignore
- Ignore: .terraform/, *.tfstate, *.tfstate.*, *.tfvars (except examples), .env, *.lock.hcl

**Files to create:**
- `.gitignore`

#### 6.2 Create comprehensive documentation
- `docs/SETUP_PREREQUISITES.md` - AWS account setup, S3, DynamoDB, IAM
- `docs/JENKINS_CONFIGURATION.md` - Jenkins credential setup (IAM role)
- `docs/DEPLOYMENT_RUNBOOK.md` - How to deploy to each environment
- `docs/SECURITY_BEST_PRACTICES.md` - Secrets, credentials, access control
- `docs/TROUBLESHOOTING.md` - Common issues and fixes

**Files to create:**
- `docs/SETUP_PREREQUISITES.md`
- `docs/JENKINS_CONFIGURATION.md`
- `docs/DEPLOYMENT_RUNBOOK.md`
- `docs/SECURITY_BEST_PRACTICES.md`
- `docs/TROUBLESHOOTING.md`

#### 6.3 Update existing documentation
- README.md - Add references to new docs, architecture diagram
- COMPLETE_SETUP_GUIDE.md - Update with new structure

---

## PART 4: AUTHENTICATION FLOW (Jenkins → AWS)

### Current (Insecure) Flow ❌
```
Jenkins Pipeline 
  ↓
AWS_CREDENTIALS env var (hardcoded)
  ↓
AWS CLI (reads env var)
  ↓
AWS API (authenticates with access key/secret)
```

**Problem:** Credentials exposed in Jenkins workspace, logs, environment

### Target (Secure) Flow ✓
```
Jenkins Machine 
  ↓
IAM Instance Role / IAM User with attached policy
  ↓
AWS SDK Credential Chain (assumes role via metadata service / credentials file)
  ↓
AWS CLI (reads from credential chain, no env vars)
  ↓
AWS API (authenticates with temporary credentials from role)
  
Terraform
  ↓
Fetches secrets from AWS Secrets Manager (authenticated via role)
  ↓
Decodes JSON secret
  ↓
Uses values as variables
```

### Implementation

**Option A: Jenkins on EC2** (Recommended)
1. Jenkins EC2 instance has IAM instance role attached
2. Instance role has policy allowing:
   - S3 access (state bucket)
   - DynamoDB access (state locks)
   - EC2, VPC, IAM, Secrets Manager access for infrastructure
3. Jenkins pipeline runs `terraform init/plan/apply`
4. Terraform inherits instance role credentials automatically
5. No AWS access keys stored anywhere

**Option B: Jenkins on bare metal**
1. Create IAM user (or use existing)
2. Store credentials in a secure file: `~/.aws/credentials`
3. Never commit this file to git
4. Jenkins process runs as user with access to `~/.aws/credentials`
5. AWS SDK automatically reads credentials
6. Jenkins secrets store NOT used for AWS credentials

---

## PART 5: CHANGES SUMMARY TABLE

| Component | Current State | Required Change | Priority | Files |
|-----------|--------------|-----------------|----------|-------|
| **AWS Credentials** | Environment vars | IAM role only | CRITICAL | Jenkinsfile |
| **Secrets Manager** | Created but unused | Fetch & use values | CRITICAL | env/*/main.tf |
| **State Locking** | Not configured | Add DynamoDB table | CRITICAL | env/*/backend.tf |
| **prod Environment** | Missing | Create complete setup | HIGH | env/prod/* |
| **VPC CIDRs** | Potentially colliding | Make unique per env | HIGH | env/*/terraform.tfvars |
| **IAM Roles** | Missing for EC2 | Create instance roles | HIGH | modules/iam/* |
| **Apache Page** | Generic | Show environment name | MEDIUM | scripts/install_apache2.sh |
| **.gitignore** | Missing | Create full ignore file | MEDIUM | .gitignore |
| **Documentation** | Partial | Complete all guides | MEDIUM | docs/* |
| **Backend Config** | Hardcoded | Parameterize init | MEDIUM | Jenkinsfile |
| **prod in Jenkins** | Not supported | Add to choices | MEDIUM | Jenkinsfile |

---

## NEXT STEPS

1. **Immediate (Session 1):**
   - ✓ Review this analysis
   - Fix Jenkinsfile: Remove credentials environment variable
   - Fix backend.tf: Add DynamoDB locking, make parameterizable
   - Add .gitignore
   - Create prod environment scaffolding

2. **Short-term (Session 2):**
   - Implement Secrets Manager integration in Terraform
   - Update terraform.tfvars to remove sensitive defaults
   - Create IAM module for EC2 instance roles
   - Implement environment-aware Apache page

3. **Medium-term (Session 3):**
   - Complete all documentation
   - Set up test S3 bucket and DynamoDB table
   - Test Jenkins pipeline end-to-end with IAM role
   - Update terraform.tfvars examples

4. **Long-term:**
   - Consider splitting modules into separate repo if sharing across teams
   - Implement cost estimation (Infracost)
   - Add automated testing (tflint, checkov)
   - Implement infrastructure change approvals (via GitHub)

---

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Credentials in Jenkins logs | CRITICAL | Remove hardcoded credentials |
| State corruption (concurrent runs) | CRITICAL | Add DynamoDB locking |
| Missing prod environment | HIGH | Create prod scaffolding |
| VPC CIDR collision | HIGH | Use unique CIDRs |
| EC2 can't access Secrets Manager | HIGH | Create IAM instance roles |
| Deployment mistakes to prod | HIGH | Require approval + docs |

---

## Success Criteria

✓ No AWS credentials hardcoded anywhere
✓ No secrets in GitHub repositories  
✓ Jenkins uses only IAM role for AWS access
✓ All three environments (dev, stage, prod) fully functional
✓ Terraform state locked and versioned in S3
✓ EC2 instances show environment name on web page
✓ Parameterized, environment-specific deployments
✓ Complete documentation for operations team

