variable "region" {
  type        = string
  description = "AWS region for the app stack."
  default     = "us-east-1"
}

variable "app_name" {
  type        = string
  description = "Application name used for resource naming."
  default     = "genlogs"
}

variable "environment" {
  type        = string
  description = "Environment name for tagging."
  default     = "dev"

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be one of: dev, qa, prod."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type."
  default     = "t3.micro"
}

variable "allowed_http_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to access the ALB over HTTP."
  default     = ["0.0.0.0/0"]
}

variable "enable_ssm" {
  type        = bool
  description = "Attach SSM permissions to the EC2 role."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Extra tags to apply."
  default     = {}
}
