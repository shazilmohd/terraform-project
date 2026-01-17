# EKS Quick Start Guide

## 🚀 Enable EKS in 2 Steps

### **Step 1: Update terraform.tfvars**
```bash
cd env/dev/
# Edit terraform.tfvars and change:
enable_eks = true
```

### **Step 2: Apply via Jenkins**
1. Go to Jenkins UI
2. Start a new build with:
   - **ENVIRONMENT**: `dev`
   - **ACTION**: `PLAN`
   - **AUTO_APPROVE**: `false`
3. Review the plan output
4. Start another build with **ACTION**: `APPLY` and **AUTO_APPROVE**: `true`

---

## 📌 What Gets Created

```
VPC (10.0.0.0/16)
├── Public Subnet 1 (10.0.1.0/24)
├── Private Subnet 1 (10.0.2.0/24)
├── Internet Gateway
└── EKS Cluster (when enable_eks = true)
    ├── Control Plane (AWS Managed)
    ├── Worker Node (1x t3.micro)
    ├── Security Groups (cluster + nodes)
    ├── IAM Roles (service role + node role)
    └── Add-ons (VPC CNI, CoreDNS, kube-proxy)
```

---

## 🔍 Verify EKS Cluster

After `terraform apply` succeeds (takes 15-20 min):

```bash
# Update kubeconfig
aws eks update-kubeconfig --region ap-south-1 --name dev-eks

# Check cluster status
kubectl cluster-info
kubectl get nodes

# View running pods
kubectl get pods -A
```

---

## 💾 Terraform Outputs

After provisioning, use:
```bash
cd env/dev/
terraform output eks_cluster_endpoint
terraform output kubeconfig_command
```

---

## 🧹 Destroy EKS

### Via Jenkins:
1. **ENVIRONMENT**: `dev`
2. **ACTION**: `DESTROY`

### Via Terraform CLI:
```bash
cd env/dev/
terraform destroy -var="enable_eks=true"
```

**⚠️ WARNING**: This deletes the EKS cluster and all data. Takes 10-15 minutes.

---

## 📊 Cost per Hour (Approximate)

| Component | Cost | Notes |
|-----------|------|-------|
| EKS Control Plane | $0.10 | Always on when cluster exists |
| t3.micro Node | $0.01-0.02 | Free tier may cover some hours |
| Data Transfer | Variable | Minimal for testing |
| **Total** | **~$0.12/hour** | **~$88/month if always on** |

**💡 Tip**: Destroy the cluster immediately after testing to avoid costs.

---

## 🛠️ File Locations

```
modules/kubernetes/eks/
├── main.tf          ← EKS cluster + IAM + add-ons
├── variables.tf     ← Configurable parameters
└── outputs.tf       ← Cluster details for kubeconfig

modules/kubernetes/security_group/
├── main.tf          ← Cluster + node security groups
├── variables.tf     ← SG configuration
└── outputs.tf       ← SG IDs

env/dev/
├── eks.tf           ← Module instantiation
├── eks-variables.tf ← EKS-specific input variables
├── eks-outputs.tf   ← Kubeconfig output
└── terraform.tfvars ← Enable flag + configuration
```

---

## ✨ Key Features

✅ Single t3.micro node (cost-optimized)  
✅ AWS-managed control plane  
✅ Optional (enable via terraform.tfvars)  
✅ Reuses existing VPC and subnets  
✅ No Jenkins changes needed  
✅ Fully automated kubeconfig generation  
✅ Production-grade IAM and security groups  

---

## ❓ FAQ

**Q: Can I keep EC2 and add EKS at the same time?**  
A: Yes! EC2 runs independently. Set `enable_eks = true` to add EKS without affecting EC2.

**Q: How do I disable EKS without destroying it?**  
A: Set `enable_eks = false` in terraform.tfvars. Running `terraform plan` won't destroy the cluster; you'd need `terraform destroy` to remove it.

**Q: Can I use this for production?**  
A: The configuration is production-ready (proper IAM, security groups, OIDC), but with 1 node for cost optimization. Scale up `eks_desired_size`, `eks_min_size`, `eks_max_size` for production workloads.

**Q: How do I deploy applications to the cluster?**  
A: Use kubectl:
```bash
kubectl apply -f my-deployment.yaml
```

**Q: Can I modify the cluster after provisioning?**  
A: Yes, update terraform.tfvars and rerun `terraform apply`. Changes like instance type, node count, cluster version are supported.

---

## 📖 Full Documentation

See `EKS_IMPLEMENTATION.md` for detailed information about:
- All input variables and defaults
- Security group rules
- IAM role policies
- Cost considerations
- Verification steps
- Module architecture
