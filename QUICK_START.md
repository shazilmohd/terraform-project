# Quick Start Guide

## Project Overview

This Terraform project provisions EC2 instances with Apache2 web servers in AWS, organized with:
- **Modules**: Reusable infrastructure components (VPC, EC2, Security Groups, Secrets Manager)
- **Environments**: Dev and Stage configurations with separate CIDR ranges and instance sizes

---

## Architecture Flow

```
AWS Secrets Manager
        ↓
   Terraform Vars
   (terraform.tfvars)
        ↓
   Environment Config
   (env/dev or env/stage)
        ↓
   Module Calls:
   ├─ VPC Module (creates VPC + subnets)
   ├─ Security Group Module (HTTP/HTTPS/SSH)
   ├─ EC2 Module (launches instances with Apache2)
   └─ Secrets Manager Module (stores secrets)
        ↓
   Deployed Resources
```

---

## Step-by-Step Deployment

### Step 1: Create AWS Secrets Manager Secret

```bash
# For Dev environment
aws secretsmanager create-secret \
  --name dev/terraform-env-vars \
  --region us-east-1 \
  --secret-string '{"db_password":"your-password","api_key":"your-api-key"}'

# For Stage environment
aws secretsmanager create-secret \
  --name stage/terraform-env-vars \
  --region us-east-1 \
  --secret-string '{"db_password":"your-password","api_key":"your-api-key"}'
```

### Step 2: Update terraform.tfvars (Optional - Only if Different from Defaults)

```bash
# Edit env/dev/terraform.tfvars
# Or use environment variables:
export TF_VAR_aws_region="us-east-1"
export TF_VAR_vpc_cidr="10.0.0.0/16"
export TF_VAR_instance_type="t2.micro"
```

### Step 3: Deploy Dev Environment

```bash
cd env/dev

# Initialize Terraform (downloads modules and providers)
terraform init

# Preview changes
terraform plan

# Apply configuration
terraform apply

# View outputs (instance IPs, VPC ID, etc.)
terraform output
```

### Step 4: Deploy Stage Environment

```bash
cd ../stage

terraform init
terraform plan
terraform apply

terraform output
```

---

## Accessing Your Apache Web Server

### Get Public IP

```bash
cd env/dev
terraform output web_server_public_ips
```

### View Apache Page in Browser

```bash
curl http://<public-ip>
# Or visit http://<public-ip> in your browser
```

You should see the Apache2 health check page with hostname and IP information.

### SSH to Instance

```bash
ssh -i /path/to/key.pem ubuntu@<public-ip>

# Inside the instance, check Apache status
sudo systemctl status apache2
sudo tail -f /var/log/apache2/access.log
```

---

## What Each Environment Provides

### Development (Dev)
- **Instance Type**: t2.micro (free tier eligible)
- **Instances**: 1
- **VPC CIDR**: 10.0.0.0/16
- **Subnets**: 1 public, 1 private
- **Purpose**: Testing, development, cost-effective

### Staging (Stage)
- **Instance Type**: t2.small (higher specs)
- **Instances**: 2 (across AZs)
- **VPC CIDR**: 10.1.0.0/16
- **Subnets**: 2 public, 2 private
- **Purpose**: Pre-production validation, load testing

---

## File Structure Explained

```
env/dev/
├── main.tf              # Module calls (VPC, EC2, Security Group, Secrets)
├── variables.tf         # Variable definitions (types, descriptions)
├── outputs.tf          # Outputs from modules
└── terraform.tfvars    # Actual values (git-ignored, safe to commit structure)

modules/networking/vpc/
├── main.tf             # VPC, subnets, IGW, routes
├── variables.tf        # VPC parameterized inputs
└── outputs.tf          # VPC outputs (IDs for use by EC2)

modules/compute/ec2/
├── main.tf             # EC2 instances with user_data
├── variables.tf        # EC2 parameterized inputs
└── outputs.tf          # Instance IDs and IPs

modules/networking/security_group/
├── main.tf             # Security group rules
├── variables.tf        # SG parameterized inputs
└── outputs.tf          # SG ID output

modules/secrets/secret_manager/
├── main.tf             # Secrets storage
├── variables.tf        # Secret name, description
└── outputs.tf          # Secret ARN, ID
```

---

## No Hardcoding - Where Values Come From

| Value | Where It Comes From | How It's Used |
|-------|-------------------|---------------|
| VPC CIDR (10.0.0.0/16) | `terraform.tfvars` | VPC module |
| Instance Type (t2.micro) | `terraform.tfvars` | EC2 module |
| Ubuntu AMI ID | Data source (dynamic) | EC2 module |
| AWS Region | `terraform.tfvars` | Provider config |
| Secret name | `terraform.tfvars` | Secrets Manager lookup |
| SSH Key Pair | `terraform.tfvars` (optional) | EC2 module |

✅ **Everything is parameterized - nothing hardcoded!**

---

## Secrets Manager Integration

The environment configuration retrieves secrets at deploy time:

```hcl
# In main.tf
data "aws_secretsmanager_secret_version" "env_secrets" {
  secret_id = var.secrets_manager_secret_name
}

locals {
  secrets = jsondecode(data.aws_secretsmanager_secret_version.env_secrets.secret_string)
}

# Access secrets in your application (e.g., env variables on EC2)
```

---

## Cleanup / Destroy

```bash
# Destroy dev environment
cd env/dev
terraform destroy

# Destroy stage environment
cd ../stage
terraform destroy

# Delete Secrets Manager secrets
aws secretsmanager delete-secret --secret-id dev/terraform-env-vars --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id stage/terraform-env-vars --force-delete-without-recovery
```

---

## Common Issues & Solutions

### Issue: "Error: Error retrieving secret"
**Solution**: Verify the secret exists in Secrets Manager
```bash
aws secretsmanager get-secret-value --secret-id dev/terraform-env-vars
```

### Issue: "No module found"
**Solution**: Run `terraform init` in the environment directory
```bash
cd env/dev
terraform init
```

### Issue: "AMI not found"
**Solution**: Data source searches for latest Ubuntu LTS. Ensure region is correct.
```bash
# Verify AMI exists in your region
aws ec2 describe-images --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" --region us-east-1
```

### Issue: "Apache2 not running"
**Solution**: SSH to instance and check logs
```bash
ssh -i key.pem ubuntu@<ip>
sudo journalctl -u cloud-final.service -n 50
curl localhost
```

---

## Git Workflow

```bash
# Clone this repo
git clone <repo-url> terraform-project

# Create a branch for changes
git checkout -b feature/add-production-env

# Edit modules (safe to commit)
vim modules/compute/ec2/variables.tf

# DON'T commit terraform.tfvars (already in .gitignore)
# DON'T commit .terraform/ directory
# DON'T commit *.tfstate files

git add modules/
git commit -m "Add new EC2 variable"
git push origin feature/add-production-env
```

---

## Next Steps

1. ✅ Create Secrets Manager secret
2. ✅ Deploy dev environment
3. ✅ Verify Apache is running
4. ✅ Deploy stage environment
5. ✅ Test load balancing with multiple instances
6. 🔄 Add production environment (copy stage config, adjust values)
7. 🔄 Integrate with CI/CD pipeline

---

## Support

For issues, check:
- `.gitignore` - Ensure sensitive files are excluded
- `terraform.tfvars` - Verify all required variables are set
- AWS Console - Check EC2, VPC, Security Groups
- Cloud-init logs - SSH to instance and check `/var/log/cloud-init-output.log`
