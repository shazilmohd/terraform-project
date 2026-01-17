variable "environment" {
  description = "Environment name (dev/stage/prod)"
  type        = string
}

variable "enable_ssm_access" {
  description = "Enable SSM Session Manager access to EC2 instances"
  type        = bool
  default     = true
}

variable "enable_s3_access" {
  description = "Enable S3 access for EC2 instances"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
