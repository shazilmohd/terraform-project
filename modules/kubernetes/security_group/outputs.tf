# EKS Security Group Module - Outputs

output "cluster_security_group_id" {
  description = "The ID of the EKS cluster security group"
  value       = aws_security_group.eks_cluster_sg.id
}

output "cluster_security_group_arn" {
  description = "The ARN of the EKS cluster security group"
  value       = aws_security_group.eks_cluster_sg.arn
}

output "node_security_group_id" {
  description = "The ID of the EKS node security group"
  value       = aws_security_group.eks_node_sg.id
}

output "node_security_group_arn" {
  description = "The ARN of the EKS node security group"
  value       = aws_security_group.eks_node_sg.arn
}
