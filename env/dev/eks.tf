# Dev Environment - EKS Configuration (Add-on)

# ============================================================================
# EKS Security Groups
# ============================================================================

module "eks_security_group" {
  count = var.enable_eks ? 1 : 0

  source = "../../modules/kubernetes/security_group"

  cluster_name = var.eks_cluster_name != "" ? var.eks_cluster_name : "${var.environment}-eks"
  vpc_id       = module.vpc.vpc_id
  environment  = var.environment

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-eks-sg"
    Terraform   = "true"
    Project     = "terraform-infrastructure"
    Component   = "eks-security-group"
  }
}

# ============================================================================
# EKS Cluster
# ============================================================================

module "eks_cluster" {
  count = var.enable_eks ? 1 : 0

  source = "../../modules/kubernetes/eks"

  cluster_name               = var.eks_cluster_name != "" ? var.eks_cluster_name : "${var.environment}-eks"
  cluster_version            = var.eks_cluster_version
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  node_instance_type         = var.eks_node_instance_type
  desired_size               = var.eks_desired_size
  min_size                   = var.eks_min_size
  max_size                   = var.eks_max_size
  disk_size                  = var.eks_disk_size
  cluster_security_group_ids = [module.eks_security_group[0].cluster_security_group_id]
  node_security_group_ids    = [module.eks_security_group[0].node_security_group_id]
  endpoint_private_access    = true
  endpoint_public_access     = true

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-eks"
    Terraform   = "true"
    Project     = "terraform-infrastructure"
    Component   = "eks-cluster"
    CreatedDate = formatdate("YYYY-MM-DD", timestamp())
  }

  depends_on = [module.vpc, module.eks_security_group]
}

# ============================================================================
# Data Source for EKS Cluster Authentication
# (Kubernetes provider configuration can be done separately when needed)
# ============================================================================

data "aws_eks_cluster_auth" "main" {
  count = var.enable_eks ? 1 : 0
  name  = module.eks_cluster[0].cluster_id
}
