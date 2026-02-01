variable "region" {
  type        = string
  description = "AWS region for the VPC."
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

variable "cidr_block" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "public_subnet_count" {
  type        = number
  description = "Number of public subnets to create."
  default     = 3
}

variable "private_subnet_count" {
  type        = number
  description = "Number of private subnets to create."
  default     = 3
}

variable "subnet_newbits" {
  type        = number
  description = "Newbits for subnetting the VPC CIDR."
  default     = 8
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Whether to provision a NAT gateway."
  default     = true
}

variable "single_nat_gateway" {
  type        = bool
  description = "Whether to provision a single NAT gateway."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Extra tags to apply."
  default     = {}
}
