# How to Use Jenkinsfile-EKS

## 📁 Files Available

| File | Purpose | Use Case |
|------|---------|----------|
| **Jenkinsfile** | Original pipeline | EC2-only, minimal overhead |
| **Jenkinsfile-EKS** | Enhanced with EKS support | EKS deployments, cluster validation |

Both files coexist in your repository. You can use either depending on your needs.

---

## 🚀 Quick Start: Using Jenkinsfile-EKS

### **Step 1: Update Jenkins Job Configuration**

#### **In Jenkins Web UI:**

1. Navigate to your Terraform job
2. Click **Configure**
3. Scroll to **Pipeline** section
4. Under "Pipeline script from SCM", change:
   - **Script Path**: `Jenkinsfile` → `Jenkinsfile-EKS`
5. Click **Save**

#### **In Jenkins Configuration File (if using Jenkins as Code):**

```groovy
pipelineJob('terraform-jenkins') {
  definition {
    cpsScm {
      scm {
        git {
          remote {
            url('https://github.com/shazilmohd/terraform-project.git')
          }
          branch('main')
        }
      }
      scriptPath('Jenkinsfile-EKS')  // Changed from 'Jenkinsfile'
    }
  }
}
```

---

### **Step 2: Verify kubectl is Installed**

Jenkinsfile-EKS uses kubectl for post-deployment validation. Install it on Jenkins agents:

#### **On Linux Jenkins Agent:**

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify installation
kubectl version --client --short
```

#### **On macOS Jenkins Agent:**

```bash
brew install kubectl
kubectl version --client --short
```

#### **On Windows Jenkins Agent:**

```powershell
# Using Chocolatey
choco install kubernetes-cli

# Or download from: https://kubernetes.io/docs/tasks/tools/
```

#### **Check from Jenkins Master:**

```bash
# SSH to Jenkins master/agent
ssh jenkins@jenkins-master
which kubectl
kubectl version --client
```

---

### **Step 3: Enable EKS in Terraform**

Update `env/dev/terraform.tfvars`:

```hcl
enable_eks = true  # Change from false
```

---

### **Step 4: Run Pipeline with EKS Parameters**

#### **In Jenkins UI:**

1. Click **Build with Parameters**
2. Configure:
   ```
   ENVIRONMENT:        dev
   ACTION:             PLAN
   AUTO_APPROVE:       false (for first time)
   VERIFY_EKS_CLUSTER: true   (to validate cluster)
   AWS_REGION:         ap-south-1
   TERRAFORM_VERSION:  1.5.0
   ```
3. Click **Build**

#### **Expected Output:**

```
✓ Pre-validation checks passed
✓ Parameter validation passed

[Terraform Init]
🔧 Backend Configuration:
   Bucket: terraform-state-1768505102
   ✓ Initialized

[Terraform Validate]
✓ Configuration is valid

[Terraform Plan]
════════════════════════════════════════════
⚠️  EKS CLUSTER DEPLOYMENT DETECTED
════════════════════════════════════════════

💰 Cost Estimate:
   - EKS Control Plane: ~$0.10/hour (~$73/month)
   - t3.micro Node: ~$0.01-0.02/hour
   - Total: ~$100-150/month when always-on

⏱️  Deployment Time:
   - Cluster creation: ~15-20 minutes
   - Node scaling: Additional 5-10 minutes

🧹 Cost Optimization Tips:
   1. Destroy cluster when not in use
   2. Use single t3.micro node (already configured)
   3. Set enable_eks = false to skip provisioning
```

---

### **Step 5: Approve and Apply**

After reviewing the plan:

1. Click **APPROVE & APPLY** in Jenkins UI
2. Wait for deployment (15-20 minutes for EKS cluster)
3. Watch for validation logs:

```
[EKS Post-Deployment Validation]
✓ EKS cluster detected - running post-deployment validation

📊 EKS Cluster Information:
   Cluster ID: dev-eks
   Endpoint: https://xxx.eks.ap-south-1.amazonaws.com

🔧 Updating kubeconfig...
✓ kubeconfig updated successfully

🔗 Verifying cluster connectivity...
✓ Cluster connectivity verified

🖥️  Checking node status...
✓ Nodes found: 1
NAME          STATUS   ROLES    AGE    VERSION
ip-10-0-x-x   Ready    <none>   1m    v1.29.x

🔌 Checking EKS add-ons status...
vpc-cni
coredns
kube-proxy

🐳 Checking system pods...
✓ System pods running:
NAMESPACE     NAME                     READY   STATUS    AGE
kube-system   aws-node-xxxxx           1/1     Running   1m
kube-system   coredns-xxxxx            1/1     Running   1m
kube-system   coredns-xxxxx            1/1     Running   1m
kube-system   kube-proxy-xxxxx         1/1     Running   1m

✓ EKS Post-Deployment Validation Complete
```

---

### **Step 6: Get Kubeconfig Instructions**

Jenkins will display:

```
╔════════════════════════════════════════════════════════════╗
║           KUBECONFIG SETUP INSTRUCTIONS                    ║
╚════════════════════════════════════════════════════════════╝

📌 To connect to your EKS cluster, run:

   aws eks update-kubeconfig --region ap-south-1 --name dev-eks

🔍 Verify connection with:

   kubectl cluster-info
   kubectl get nodes
   kubectl get pods -A
```

---

### **Step 7: Access Your Cluster**

From your local machine:

```bash
# Update kubeconfig (copy the command from Jenkins output)
aws eks update-kubeconfig --region ap-south-1 --name dev-eks

# Verify cluster
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Deploy an application
kubectl create deployment hello-world --image=nginx
kubectl expose deployment hello-world --type=LoadBalancer --port=80 --target-port=80
kubectl get services
```

---

## 🔄 Switching Back to Original Jenkinsfile

If you want to revert to the original:

1. In Jenkins: **Configure** → **Script Path**: `Jenkinsfile-EKS` → `Jenkinsfile`
2. Save and run normally

⚠️ Note: You'll lose EKS validation features, but core Terraform functionality remains unchanged.

---

## 🛠️ Troubleshooting

### **Issue: kubectl command not found**

**Error in Jenkins logs:**
```
⚠️  kubectl not found - EKS cluster verification will be skipped
```

**Solution:**
1. Install kubectl on Jenkins agent
2. Verify: `which kubectl` returns `/usr/local/bin/kubectl` or similar
3. Re-run the Jenkins build

### **Issue: Cluster validation times out**

**Error in Jenkins logs:**
```
⚠️  No nodes found yet - cluster still initializing
```

**This is normal.** EKS clusters take 2-3 minutes for nodes to join.

**Solution:**
1. Wait a few minutes
2. Run validation manually: `kubectl get nodes`
3. Nodes will appear when ready

### **Issue: kubeconfig command not found**

**Error:**
```
EKS cluster not detected in this deployment
```

**Cause:** `enable_eks = false` in terraform.tfvars

**Solution:**
1. Set `enable_eks = true`
2. Run `terraform apply` again
3. Kubeconfig command will appear in output

### **Issue: AWS credentials not working**

**Error:**
```
Unable to assume service account role
```

**Solution:**
1. Verify Jenkins agent has AWS credentials configured
2. Check IAM permissions (EC2, EKS, VPC, IAM, Secrets Manager)
3. Verify AWS_REGION is set to `ap-south-1`

---

## 📊 Feature Comparison Quick Reference

| Feature | Original | EKS-Enhanced |
|---------|----------|---|
| Core Terraform (EC2) | ✅ | ✅ |
| EKS Deployment | ✅ | ✅ |
| EKS Validation | ❌ | ✅ |
| Auto kubeconfig | ❌ | ✅ |
| Cost Warnings | ❌ | ✅ |
| Node Checks | ❌ | ✅ |
| kubectl Required | ❌ | ✅ |

---

## 📌 Key Points

✅ **Backward Compatible**: Jenkinsfile-EKS works with EC2-only deployments (EKS stages are skipped)

✅ **Optional EKS Validation**: Set `VERIFY_EKS_CLUSTER=false` to skip validation if kubectl is unavailable

✅ **No Breaking Changes**: Existing Terraform configurations continue to work

✅ **Automatic Detection**: Jenkinsfile-EKS auto-detects EKS in plan and shows appropriate messages

✅ **Production Ready**: Includes all safety guards, approvals, and rollback protection

---

## 🎯 Next Steps

1. ✅ Choose which Jenkinsfile to use
2. ✅ Update Jenkins job configuration
3. ✅ Install kubectl (if using Jenkinsfile-EKS)
4. ✅ Set `enable_eks = true` in terraform.tfvars
5. ✅ Run pipeline with PLAN action
6. ✅ Review EKS cost warnings
7. ✅ Approve and deploy
8. ✅ Watch automatic cluster validation
9. ✅ Use kubeconfig command to access cluster

Enjoy your EKS cluster! 🎉
