# Dev Environment - EKS Outputs (Add-on)

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = try(module.eks_cluster[0].cluster_id, null)
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = try(module.eks_cluster[0].cluster_endpoint, null)
}

output "eks_cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = try(module.eks_cluster[0].cluster_version, null)
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = try(module.eks_cluster[0].cluster_arn, null)
}

output "eks_node_group_id" {
  description = "EKS node group ID"
  value       = try(module.eks_cluster[0].node_group_id, null)
}

output "eks_node_iam_role_arn" {
  description = "IAM role ARN for EKS worker nodes"
  value       = try(module.eks_cluster[0].node_iam_role_arn, null)
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = try(module.eks_security_group[0].cluster_security_group_id, null)
}

output "eks_node_security_group_id" {
  description = "EKS node security group ID"
  value       = try(module.eks_security_group[0].node_security_group_id, null)
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate authority data for the cluster"
  value       = try(module.eks_cluster[0].cluster_certificate_authority_data, null)
  sensitive   = true
}

output "eks_cluster_oidc_issuer_url" {
  description = "The URL of the EKS cluster OIDC Issuer"
  value       = try(module.eks_cluster[0].cluster_oidc_issuer_url, null)
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig with EKS cluster details"
  value = var.enable_eks ? format(
    "aws eks update-kubeconfig --region %s --name %s",
    var.aws_region,
    module.eks_cluster[0].cluster_id
  ) : null
}
