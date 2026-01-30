variable "region" {
  type        = string
  description = "AWS region for the bootstrap resources."
  default     = "us-east-1"

  validation {
    condition     = length(trimspace(var.region)) > 0
    error_message = "region must be a non-empty string."
  }
}

variable "bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for Terraform state (defaults to <app_name>-state-file)."
  default     = ""

  validation {
    condition = var.bucket_name == "" || (
      length(var.bucket_name) >= 3 &&
      length(var.bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9.-]+[a-z0-9]$", var.bucket_name)) &&
      !can(regex("\\.\\.", var.bucket_name))
    )
    error_message = "bucket_name must be empty or a valid S3 bucket name (3-63 chars, lowercase, digits, dots, hyphens)."
  }
}

variable "app_name" {
  type        = string
  description = "Application name used for resource naming."
  default     = "genlogs"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.app_name))
    error_message = "app_name must be 3-32 chars, lowercase, start with a letter, and contain only letters, numbers, or hyphens."
  }
}

variable "force_destroy" {
  type        = bool
  description = "Whether to force destroy the state bucket."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Common tags to apply to bootstrap resources."
  default = {
    app         = "genlogs"
    managedby   = "terraform"
    project     = "genlogs-poc"
    component   = "bootstrap"
    environment = "development"
    owner       = "DevOps"
  }

  validation {
    condition     = length(var.tags) > 0
    error_message = "tags must include at least one key."
  }
}

variable "github_org" {
  type        = string
  description = "GitHub organization or user that owns the repo."
  default     = "soworks"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]{0,38}$", var.github_org))
    error_message = "github_org must be a valid GitHub org/user name."
  }
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name that will assume the OIDC role."
  default     = "aws-terraform-poc"

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "github_repo must be a valid GitHub repository name."
  }
}
