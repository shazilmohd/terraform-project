# Dev Environment - EKS Variables (Add-on)

# EKS Cluster Configuration
variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = ""
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.micro"
}

variable "eks_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_disk_size" {
  description = "EBS root volume size for EKS nodes in GB"
  type        = number
  default     = 20
}

variable "enable_eks" {
  description = "Enable EKS cluster provisioning"
  type        = bool
  default     = false
}
