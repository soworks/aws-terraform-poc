variable "app_name" {
  type        = string
  description = "Application name used for resource naming."
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

  validation {
    condition     = var.public_subnet_count >= 1 && var.public_subnet_count <= 6
    error_message = "public_subnet_count must be between 1 and 6."
  }
}

variable "private_subnet_count" {
  type        = number
  description = "Number of private subnets to create."
  default     = 3

  validation {
    condition     = var.private_subnet_count >= 1 && var.private_subnet_count <= 6
    error_message = "private_subnet_count must be between 1 and 6."
  }
}

variable "subnet_newbits" {
  type        = number
  description = "Newbits for subnetting the VPC CIDR."
  default     = 8

  validation {
    condition     = var.subnet_newbits >= 1 && var.subnet_newbits <= 10
    error_message = "subnet_newbits must be between 1 and 10."
  }
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Whether to provision a NAT gateway for private subnets."
  default     = true
}

variable "single_nat_gateway" {
  type        = bool
  description = "Whether to provision a single NAT gateway."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Common tags to apply to VPC resources."
  default     = {}
}

variable "public_subnet_map_public_ip_on_launch" {
  type        = bool
  description = "Whether public subnets should assign public IPs on launch."
  default     = true
}

variable "enable_dns_hostnames" {
  type        = bool
  description = "Enable DNS hostnames in the VPC."
  default     = true
}

variable "enable_dns_support" {
  type        = bool
  description = "Enable DNS support in the VPC."
  default     = true
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

variable "owner" {
  type        = string
  description = "Owner tag value."
  default     = "DevOps"
}

variable "project" {
  type        = string
  description = "Project tag value."
  default     = "genlogs-poc"
}
