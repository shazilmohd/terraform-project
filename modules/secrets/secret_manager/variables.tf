variable "secret_name" {
  description = "Name of the secret"
  type        = string
}

variable "description" {
  description = "Description of the secret"
  type        = string
  default     = ""
}

variable "recovery_window_in_days" {
  description = "Number of days for secret recovery (7-30)"
  type        = number
  default     = 7
}

variable "secret_string" {
  description = "Secret string value"
  type        = string
  sensitive   = true
  default     = ""
}

variable "secret_binary" {
  description = "Secret binary value"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
