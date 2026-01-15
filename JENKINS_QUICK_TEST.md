# Jenkins Pipeline - Quick Test Guide

## The Error (FIXED ✅)

```
ERROR: Error fetching remote repo 'origin'
hudson.plugins.git.GitException: Failed to fetch from ${env.GIT_REPO_URL}
```

**Root Cause**: Duplicate checkout stage trying to use undefined variables

**Solution**: Removed redundant checkout stage - Jenkins handles it automatically!

---

## Fixed Code Already Pushed ✓

```bash
Commit: cb856d9
Message: Fix: Remove duplicate checkout stage causing variable expansion errors
Branch: master
Status: Pushed to GitHub ✅
```

---

## How to Test the Fixed Pipeline

### Step 1: Ensure Jenkins Is Running

```bash
# Check Jenkins status
sudo systemctl status jenkins

# If not running:
sudo systemctl start jenkins

# Access Jenkins:
# Browser: http://localhost:8080
# Or: http://YOUR-SERVER-IP:8080
```

### Step 2: Verify Job Configuration

```
Jenkins Dashboard
→ terraform-provisioning job
→ Configure
→ Pipeline section:
   Definition: Pipeline script from SCM
   SCM: Git
   Repository URL: https://github.com/shazilmohd/terraform-project.git
   Branch: */master
   Script Path: Jenkinsfile
→ Save
```

### Step 3: Build with Parameters

```
Jenkins Dashboard
→ terraform-provisioning
→ Build with Parameters

Select:
- ENVIRONMENT: dev
- ACTION: PLAN (just planning, not creating yet)
- AUTO_APPROVE: false (need approval for apply)
- AWS_REGION: ap-south-1
- TERRAFORM_VERSION: 1.5.0

Click: Build
```

### Step 4: Watch the Build

```
Jenkins shows:
├─ #1 (Build number)
├─ Pipeline: Checking out...
├─ Stage: Pre-Validation
│  └─ ✓ Terraform installed
│  └─ ✓ AWS CLI installed
│  └─ ✓ AWS credentials valid
├─ Stage: Terraform Init
│  └─ ✓ Downloading AWS provider
├─ Stage: Terraform Validate
│  └─ ✓ Syntax valid
├─ Stage: Terraform Plan
│  └─ ✓ Plan generated (12 resources)
├─ Stage: Review Plan
│  └─ Shows plan output
└─ Waiting for approval (if ACTION=APPLY)
```

---

## Expected Success Output

```
18:34:55  ========== Checking out source code ==========
18:34:56  ✓ Code checked out from GitHub

18:34:57  ========== Running pre-deployment validation ==========
18:35:01  ✓ Terraform v1.5.0 on linux_amd64
18:35:02  ✓ AWS CLI v2.13.x
18:35:03  ✓ AWS credentials valid
18:35:04  ✓ All pre-validation checks passed

18:35:05  ========== Initializing Terraform ==========
18:35:15  ✓ Terraform has been successfully initialized

18:35:16  ========== Validating Terraform configuration ==========
18:35:17  ✓ Success! The configuration is valid.

18:35:18  ========== Checking Terraform format ==========
18:35:19  ✓ All files properly formatted

18:35:20  ========== Creating Terraform plan ==========
18:35:30  ========== Terraform Plan Output ==========
Plan: 12 to add, 0 to change, 0 to destroy

18:35:31  ========== Waiting for approval ==========
Stage "Approval" waiting...
```

---

## If Still Getting Error

### Check Jenkins Logs

```bash
# Jenkins logs
sudo tail -100 /var/log/jenkins/jenkins.log

# Or view in Jenkins UI:
Jenkins → Manage Jenkins → System Log
```

### Verify Jenkinsfile Updated

```bash
# Confirm the fix is in GitHub
git log --oneline | grep "Fix: Remove"

# Should show:
# cb856d9 Fix: Remove duplicate checkout stage...
```

### Verify Jenkins Sees Latest Code

```
Jenkins Dashboard
→ terraform-provisioning job
→ Build Now (forces fresh checkout)

Jenkins will pull latest code from GitHub
```

---

## Pipeline Flow (NOW CORRECT)

```
Pipeline Start
    │
    ├─ Declarative Checkout ✓ (Git SCM)
    │  └─ Automatically checks out GitHub repo
    │
    ├─ Stage: Pre-Validation ✓
    │  └─ Checks tools, AWS credentials, directories
    │
    ├─ Stage: Terraform Init ✓
    │  └─ Downloads AWS provider
    │
    ├─ Stage: Terraform Validate ✓
    │  └─ Checks syntax
    │
    ├─ Stage: Terraform Format Check ✓
    │  └─ Checks code formatting
    │
    ├─ Stage: Terraform Plan ✓
    │  └─ Generates execution plan
    │
    ├─ Stage: Review Plan ✓
    │  └─ Displays plan to console
    │
    ├─ Stage: Approval ✓ (if ACTION=APPLY)
    │  └─ Waits for human approval
    │
    ├─ Stage: Terraform Apply ✓ (if approved)
    │  └─ Creates resources in AWS
    │
    ├─ Stage: Output Artifacts ✓
    │  └─ Saves outputs, summary, state
    │
    ├─ Stage: State Backup ✓
    │  └─ Backs up Terraform state file
    │
    └─ Post Actions ✓
       └─ Cleanup, success/failure reporting
```

---

## Testing Scenarios

### Scenario 1: Just Planning (Safe Test)

```
Build Parameters:
- ENVIRONMENT: dev
- ACTION: PLAN ← Just see what would happen
- AUTO_APPROVE: false
- AWS_REGION: ap-south-1

Result:
✓ Terraform plan generated
✓ Shows 12 resources to be created
✓ Does NOT create anything yet!
✓ Safe to test!
```

### Scenario 2: Full Deployment

```
Build Parameters:
- ENVIRONMENT: dev
- ACTION: APPLY ← Create actual resources
- AUTO_APPROVE: false ← Need approval
- AWS_REGION: ap-south-1

Pipeline will:
1. Run terraform plan
2. Show plan output
3. Wait for approval (30 min timeout)
4. You click "APPROVE & APPLY" in Jenkins
5. terraform apply runs
6. Resources created in AWS!
```

### Scenario 3: Destroy Infrastructure

```
Build Parameters:
- ENVIRONMENT: dev
- ACTION: DESTROY ← Delete all resources
- AWS_REGION: ap-south-1

Pipeline will:
1. Show destruction warning
2. Wait for confirmation
3. Delete all resources
4. Infrastructure gone!

⚠️  WARNING: Irreversible operation!
```

---

## Troubleshooting

### If Build Still Fails

**Check 1: Jenkins SCM Configuration**
```
Jenkins Job → Configure
→ Pipeline section
→ Definition: Pipeline script from SCM ✓
→ SCM: Git ✓
→ Repository URL: https://github.com/shazilmohd/terraform-project.git ✓
→ Branch: */master ✓
```

**Check 2: Jenkinsfile Location**
```
Repository root should have:
✓ Jenkinsfile (no file extension)
✓ env/dev/
✓ modules/
✓ jenkins.env
```

**Check 3: Git Credentials**
```
Jenkins → Manage Credentials → Global
Should have at least:
✓ aws-credentials (AWS)
✓ secrets-manager-secret-id (Secrets Manager)
```

**Check 4: Jenkins Has Tools**
```bash
# SSH into Jenkins server
# Check if installed:
which terraform
which aws
which git

# If missing, install:
sudo apt-get install -y terraform awscli git
```

### Build Hangs at Approval Stage

```
This is NORMAL if ACTION=APPLY and AUTO_APPROVE=false

Jenkins waits for approval for 30 minutes.

To approve:
1. Go to Jenkins console
2. Look for approval button/link
3. Click "APPROVE & APPLY"
4. Build continues
```

---

## What to Do Next

✅ **Jenkinsfile is fixed!**

1. **Verify GitHub has latest code**
   ```bash
   git log --oneline | head -3
   # Should show fix commit
   ```

2. **Go to Jenkins and build**
   ```
   Jenkins → terraform-provisioning
   → Build with Parameters
   → ENVIRONMENT: dev
   → ACTION: PLAN
   → Build
   ```

3. **Watch build succeed**
   ```
   Console should show all stages passing
   Plan will show 12 resources ready to deploy
   ```

4. **Once confident, deploy**
   ```
   → Build with Parameters
   → ACTION: APPLY
   → Build
   → Approve when asked
   → Infrastructure created!
   ```

---

## Success Checklist

```
✅ Jenkinsfile updated and pushed
✅ No duplicate checkout stage
✅ Pre-Validation is first stage
✅ Environment variables properly set
✅ Jenkins job configured
✅ AWS credentials in Jenkins
✅ Secrets Manager credential in Jenkins
✅ First test build shows green checkmark
✅ Terraform plan generates successfully
✅ Ready for deployment!
```

**You're all set! Next: Run the pipeline! 🚀**
