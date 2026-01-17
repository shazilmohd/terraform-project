# IAM Instance Role for EC2
# Provides permissions for:
# - Accessing AWS Secrets Manager
# - CloudWatch logging
# - S3 access if needed
# - SSM Session Manager (optional)

resource "aws_iam_role" "ec2_instance_role" {
  name = "${var.environment}-ec2-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-ec2-instance-role"
    }
  )
}

# IAM instance profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.environment}-ec2-instance-profile"
  role = aws_iam_role.ec2_instance_role.name
}

# Policy for Secrets Manager access
resource "aws_iam_role_policy" "secrets_manager_access" {
  name = "${var.environment}-secrets-manager-access"
  role = aws_iam_role.ec2_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.environment}/*"
      }
    ]
  })
}

# Policy for CloudWatch logging
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "${var.environment}-cloudwatch-logs"
  role = aws_iam_role.ec2_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Optional: Policy for SSM Session Manager (for secure shell access without SSH keys)
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  count              = var.enable_ssm_access ? 1 : 0
  role               = aws_iam_role.ec2_instance_role.name
  policy_arn         = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Optional: Policy for S3 access if needed for backups/artifacts
resource "aws_iam_role_policy" "s3_access" {
  count = var.enable_s3_access ? 1 : 0
  name  = "${var.environment}-s3-access"
  role  = aws_iam_role.ec2_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::*/${var.environment}/*"
      }
    ]
  })
}
