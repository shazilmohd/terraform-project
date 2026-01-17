# EKS Security Group Module - Main Configuration

# ============================================================================
# EKS Cluster Security Group
# ============================================================================

resource "aws_security_group" "eks_cluster_sg" {
  name_prefix = "${var.cluster_name}-cluster-"
  description = "Security group for EKS cluster ${var.cluster_name} control plane"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-cluster-sg"
    }
  )
}

# Allow inbound HTTPS from VPC (for API server access)
resource "aws_vpc_security_group_ingress_rule" "cluster_from_nodes" {
  description       = "Allow nodes to communicate with the cluster API"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.eks_cluster_sg.id
  referenced_security_group_id = aws_security_group.eks_node_sg.id
}

# Allow inbound from cluster security group itself (for pod-to-pod communication)
resource "aws_vpc_security_group_ingress_rule" "cluster_self" {
  description       = "Allow cluster to communicate with itself"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.eks_cluster_sg.id
  referenced_security_group_id = aws_security_group.eks_cluster_sg.id
}

# Allow all outbound from cluster
resource "aws_vpc_security_group_egress_rule" "cluster_all_outbound" {
  description       = "Allow all outbound traffic from cluster"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.eks_cluster_sg.id
}

# ============================================================================
# EKS Node Security Group
# ============================================================================

resource "aws_security_group" "eks_node_sg" {
  name_prefix = "${var.cluster_name}-node-"
  description = "Security group for EKS worker nodes in ${var.cluster_name}"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-node-sg"
    }
  )
}

# Allow nodes to communicate with each other (kubelet)
resource "aws_vpc_security_group_ingress_rule" "node_self" {
  description       = "Allow nodes to communicate with each other"
  from_port         = 1025
  to_port           = 65535
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.eks_node_sg.id
  referenced_security_group_id = aws_security_group.eks_node_sg.id
}

# Allow pods to communicate with each other
resource "aws_vpc_security_group_ingress_rule" "node_self_udp" {
  description       = "Allow pods to communicate with each other (UDP)"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  security_group_id = aws_security_group.eks_node_sg.id
  referenced_security_group_id = aws_security_group.eks_node_sg.id
}

# Allow cluster to communicate with nodes
resource "aws_vpc_security_group_ingress_rule" "node_from_cluster" {
  description       = "Allow cluster to communicate with nodes"
  from_port         = 1025
  to_port           = 65535
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.eks_node_sg.id
  referenced_security_group_id = aws_security_group.eks_cluster_sg.id
}

# Allow SSH from VPC (for debugging - restrict in production)
resource "aws_vpc_security_group_ingress_rule" "node_ssh" {
  description       = "Allow SSH access to nodes (restrict in production)"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.eks_node_sg.id
}

# Allow all outbound from nodes
resource "aws_vpc_security_group_egress_rule" "node_all_outbound" {
  description       = "Allow all outbound traffic from nodes"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.eks_node_sg.id
}

# ============================================================================
# Additional Ingress Rules (Optional)
# ============================================================================

resource "aws_vpc_security_group_ingress_rule" "node_additional" {
  for_each = { for idx, rule in var.additional_ingress_rules : idx => rule }

  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = length(each.value.cidr_blocks) > 0 ? each.value.cidr_blocks[0] : null
  security_group_id = aws_security_group.eks_node_sg.id
}
