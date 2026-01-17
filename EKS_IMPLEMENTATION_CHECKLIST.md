# EKS Implementation Checklist & File Manifest

## ✅ IMPLEMENTATION VERIFICATION

### Terraform Modules
- [x] `modules/kubernetes/eks/main.tf` - EKS cluster + IAM + add-ons
- [x] `modules/kubernetes/eks/variables.tf` - Input variables
- [x] `modules/kubernetes/eks/outputs.tf` - Cluster outputs
- [x] `modules/kubernetes/security_group/main.tf` - Security groups
- [x] `modules/kubernetes/security_group/variables.tf` - SG variables
- [x] `modules/kubernetes/security_group/outputs.tf` - SG outputs

### Dev Environment Files
- [x] `env/dev/eks.tf` - Module instantiation
- [x] `env/dev/eks-variables.tf` - EKS variables
- [x] `env/dev/eks-outputs.tf` - EKS outputs
- [x] `env/dev/terraform.tfvars` - Updated with EKS defaults

### Jenkins Pipelines
- [x] `Jenkinsfile` - Original (unchanged)
- [x] `Jenkinsfile-EKS` - Enhanced with EKS features

### Documentation
- [x] `EKS_QUICK_REFERENCE.md` - Quick lookup
- [x] `EKS_QUICK_START.md` - 2-minute setup
- [x] `EKS_IMPLEMENTATION.md` - Technical guide
- [x] `JENKINSFILE_ANALYSIS.md` - Pipeline comparison
- [x] `JENKINSFILE_EKS_SETUP.md` - Jenkins configuration
- [x] `EKS_COMPLETE_SUMMARY.md` - Full overview
- [x] `EKS_IMPLEMENTATION_CHECKLIST.md` - This file

---

## 📋 PRE-DEPLOYMENT CHECKLIST

### Prerequisites
- [ ] AWS account with Free Tier eligible or credit
- [ ] Jenkins with git integration configured
- [ ] AWS CLI installed and configured on Jenkins agents
- [ ] kubectl installed on Jenkins agents (for Jenkinsfile-EKS)
- [ ] Terraform 1.5.0+ installed on Jenkins agents

### Repository Preparation
- [ ] Git repository cloned and configured
- [ ] Existing Terraform code working (EC2 deployment tested)
- [ ] SSH access to Jenkins agents
- [ ] Jenkins job configured to use this repository

### AWS Configuration
- [ ] AWS credentials configured in Jenkins (IAM user with permissions)
- [ ] S3 bucket for Terraform state exists (terraform-state-1768505102)
- [ ] DynamoDB table for state locks exists (terraform-locks)
- [ ] IAM permissions include: EC2, EKS, VPC, IAM, Secrets Manager, S3

---

## 🚀 DEPLOYMENT CHECKLIST

### Step 1: Review Documentation
- [ ] Read `EKS_QUICK_REFERENCE.md` (5 minutes)
- [ ] Skim `JENKINSFILE_ANALYSIS.md` to understand pipeline changes
- [ ] Review `EKS_IMPLEMENTATION.md` for technical details

### Step 2: Update Configuration
- [ ] Edit `env/dev/terraform.tfvars`
  - [ ] Change `enable_eks = false` → `enable_eks = true`
  - [ ] Verify other settings (region, instance type, etc.)
- [ ] Optional: Adjust EKS parameters
  - [ ] `eks_cluster_version` (default: 1.29)
  - [ ] `eks_node_instance_type` (default: t3.micro)
  - [ ] `eks_desired_size` (default: 1)

### Step 3: Update Jenkins Job
- [ ] Log into Jenkins web UI
- [ ] Navigate to your Terraform job
- [ ] Click "Configure"
- [ ] Find "Pipeline" section
- [ ] Change "Script Path" from `Jenkinsfile` to `Jenkinsfile-EKS`
- [ ] Click "Save"

### Step 4: Install kubectl on Jenkins Agents
- [ ] SSH into Jenkins master/agent machines
- [ ] Run kubectl installation:
  ```bash
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
  kubectl version --client
  ```
- [ ] Verify: `which kubectl` returns a path
- [ ] Verify: `kubectl version --client --short` shows version

### Step 5: Test Pipeline - PLAN Stage
- [ ] In Jenkins UI, click "Build with Parameters"
- [ ] Set parameters:
  ```
  ENVIRONMENT:        dev
  ACTION:             PLAN
  AUTO_APPROVE:       false
  VERIFY_EKS_CLUSTER: true
  AWS_REGION:         ap-south-1
  TERRAFORM_VERSION:  1.5.0
  ```
- [ ] Click "Build"
- [ ] Wait for build to complete (2-3 minutes)
- [ ] Verify output contains:
  - [ ] `✓ All pre-validation checks passed`
  - [ ] `⚠️  EKS CLUSTER DEPLOYMENT DETECTED`
  - [ ] `💰 Cost Estimate: ~$0.10/hour`
  - [ ] `Terraform plan output created successfully`

### Step 6: Review Plan Output
- [ ] Check Jenkins console output for:
  - [ ] `aws_eks_cluster` resource creation
  - [ ] `aws_eks_node_group` resource creation
  - [ ] IAM roles and policies
  - [ ] Security groups
- [ ] Note the plan summary (number of resources to create)

### Step 7: Approve and Apply
- [ ] If plan looks good, start another build with:
  ```
  ENVIRONMENT:        dev
  ACTION:             APPLY
  AUTO_APPROVE:       true (for speed, or false for approval prompt)
  VERIFY_EKS_CLUSTER: true
  ```
- [ ] Click "Build"
- [ ] Watch the console output for:
  - [ ] `Initializing Terraform...` ✓
  - [ ] `Applying Terraform...` ✓
  - [ ] `EKS cluster deployment starting...` ✓

### Step 8: Wait for Cluster Creation
- [ ] Cluster creation takes 15-20 minutes
- [ ] Watch for progress in console:
  - [ ] `aws_eks_cluster.main` created (usually first 10-15 min)
  - [ ] `aws_eks_node_group.main` created (next 5-10 min)
  - [ ] `aws_eks_addon` resources created (1-2 min)

### Step 9: Post-Deployment Validation
- [ ] Watch for EKS validation stage:
  - [ ] `✓ EKS cluster detected`
  - [ ] `📊 EKS Cluster Information` displayed
  - [ ] `🔧 Updating kubeconfig...`
  - [ ] `🔗 Verifying cluster connectivity...`
  - [ ] `✓ Cluster connectivity verified`

### Step 10: Node Readiness Verification
- [ ] Look for node status check:
  - [ ] `🖥️  Checking node status...`
  - [ ] `✓ Nodes found: 1` (should show 1 node)
  - [ ] Node information displayed (NAME, STATUS, ROLES, etc.)

### Step 11: Get Kubeconfig Instructions
- [ ] In console output, find:
  ```
  ╔════════════════════════════════════════════════════════════╗
  ║           KUBECONFIG SETUP INSTRUCTIONS                    ║
  ╚════════════════════════════════════════════════════════════╝
  
  📌 To connect to your EKS cluster, run:
  
     aws eks update-kubeconfig --region ap-south-1 --name dev-eks
  ```
- [ ] Copy this command to safe location

### Step 12: Update Kubeconfig on Local Machine
- [ ] On your local machine (laptop/desktop), run:
  ```bash
  aws eks update-kubeconfig --region ap-south-1 --name dev-eks
  ```
- [ ] Verify: `kubectl cluster-info`
- [ ] Should show EKS cluster endpoint

### Step 13: Verify Cluster Access
- [ ] Run: `kubectl get nodes`
  - [ ] Should show 1 node with STATUS=Ready
- [ ] Run: `kubectl get pods -A`
  - [ ] Should show system pods running (coredns, aws-node, kube-proxy)

### Step 14: Review Artifacts
- [ ] In Jenkins job, check "Build Artifacts"
- [ ] Should contain:
  - [ ] `terraform_outputs_*.json` (cluster endpoint, etc.)
  - [ ] `deployment_summary_*.txt` (readable summary)
  - [ ] `ARTIFACT_SECURITY_*.txt` (security notes)

---

## 🧪 VERIFICATION TESTS

### Test 1: Cluster Connectivity
```bash
kubectl cluster-info
# Should show: Kubernetes master is running at https://...
```

### Test 2: Node Status
```bash
kubectl get nodes
# Should show: 1 node with STATUS=Ready
```

### Test 3: Pod Status
```bash
kubectl get pods -A
# Should show:
# - kube-system pods (coredns, aws-node, kube-proxy)
# - All pods should be Running
```

### Test 4: Deploy Test Workload
```bash
kubectl create deployment test --image=nginx
kubectl expose deployment test --type=LoadBalancer --port=80
kubectl get services
# Should show test service with EXTERNAL-IP
```

### Test 5: Scale Test
```bash
# Edit eks_desired_size to 2 in terraform.tfvars
# Run Jenkins PLAN and APPLY
# Should add second node

# To revert:
# Edit eks_desired_size back to 1
# Run Jenkins PLAN and APPLY
```

---

## ⚠️ TROUBLESHOOTING CHECKLIST

### Issue: kubectl command not found
- [ ] Verify kubectl installed: `which kubectl`
- [ ] Check PATH: `echo $PATH`
- [ ] Reinstall if needed: `curl -LO https://...kubectl && sudo mv kubectl /usr/local/bin/`

### Issue: Nodes not ready after 30 minutes
- [ ] Wait additional 2-3 minutes (clusters are slow)
- [ ] Check AWS EC2 console for instances
- [ ] Check instance logs in EC2 console
- [ ] Try: `kubectl describe nodes` for detailed status

### Issue: Cannot connect with kubeconfig command
- [ ] Verify AWS credentials: `aws sts get-caller-identity`
- [ ] Try: `aws eks describe-cluster --name dev-eks --region ap-south-1`
- [ ] Check if cluster exists in AWS console
- [ ] Verify region matches (ap-south-1)

### Issue: Jenkins pipeline times out
- [ ] EKS cluster creation takes 15-20 minutes
- [ ] Pipeline timeout is set to 1 hour (should be enough)
- [ ] Check CloudFormation events in AWS console
- [ ] Increase timeout if needed: Jenkins Job Config → Options → Timeout

### Issue: Cost is higher than expected
- [ ] Verify only 1 node: `kubectl get nodes` should show 1
- [ ] Check no extra resources created: AWS Console → EC2
- [ ] Run DESTROY if not needed to stop incurring costs

### Issue: Destroy hangs
- [ ] Pods may take time to terminate gracefully
- [ ] Cancel and retry: Jenkins → Click "Stop Build" → Retry
- [ ] Check AWS console for resources still being deleted
- [ ] Verify no errors in Terraform logs

---

## 📊 ROLLBACK PROCEDURE

### If Something Goes Wrong:

#### Option 1: Keep EKS Running, Fix Configuration
```bash
# Edit env/dev/terraform.tfvars
enable_eks = true  # Keep it enabled

# Fix whatever was wrong
# Run Jenkins PLAN to see what changed
# Run Jenkins APPLY to apply fixes
```

#### Option 2: Disable EKS Without Destroying
```bash
# Edit env/dev/terraform.tfvars
enable_eks = false  # Disable provisioning

# Run Jenkins APPLY
# Cluster continues running but Terraform stops managing it
# Manually delete via AWS console if needed
```

#### Option 3: Complete Destroy
```bash
# In Jenkins:
# ENVIRONMENT: dev
# ACTION: DESTROY
# Confirm when prompted

# This completely removes EKS cluster and all resources
# Takes 10-15 minutes
```

---

## 📈 NEXT STEPS AFTER DEPLOYMENT

- [ ] Deploy test application to EKS
- [ ] Setup monitoring (CloudWatch, Prometheus)
- [ ] Setup logging (CloudWatch Logs, ELK)
- [ ] Configure ingress controller
- [ ] Setup auto-scaling (if needed)
- [ ] Enable IRSA for service account access
- [ ] Plan scaling to stage environment
- [ ] Document custom configurations
- [ ] Train team on kubectl and EKS operations
- [ ] Setup backup and disaster recovery

---

## 📞 SUPPORT & REFERENCES

### Key Commands
```bash
# Cluster info
aws eks describe-cluster --name dev-eks --region ap-south-1

# Update kubeconfig
aws eks update-kubeconfig --region ap-south-1 --name dev-eks

# List resources
kubectl get all
kubectl get nodes
kubectl get pods -A

# View logs
kubectl logs -n kube-system pod_name

# Describe resources
kubectl describe node node_name
kubectl describe pod pod_name
```

### Documentation
- AWS EKS Docs: https://docs.aws.amazon.com/eks/
- kubectl Cheat Sheet: https://kubernetes.io/docs/reference/kubectl/cheatsheet/
- Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/

### Useful Links
- EKS User Guide: https://docs.aws.amazon.com/eks/latest/userguide/
- Kubernetes Official: https://kubernetes.io/
- AWS CLI Reference: https://docs.aws.amazon.com/cli/

---

## ✅ FINAL VERIFICATION

After successful deployment, verify:

- [x] EKS cluster visible in AWS console (EKS → Clusters)
- [x] Worker node visible in EC2 console (Instances)
- [x] Node shows as Ready: `kubectl get nodes`
- [x] System pods running: `kubectl get pods -n kube-system`
- [x] Test deployment successful: `kubectl create deployment test --image=nginx`
- [x] Jenkins artifacts generated and accessible
- [x] kubeconfig working from local machine
- [x] Terraform state file updated in S3 backend
- [x] No security group or IAM errors in logs
- [x] Cost monitoring setup (optional but recommended)

---

## 🎉 DEPLOYMENT COMPLETE!

Your EKS cluster is now ready for:
- Development and testing
- Application deployments
- Kubernetes experimentation
- CI/CD pipeline testing

Remember:
✅ Cluster is optional (set `enable_eks = false` to disable)
✅ EC2 instance continues running independently
✅ Cost ~$100-150/month when always-on
✅ Destroy to save costs when not in use

For questions, refer to the comprehensive documentation files!
