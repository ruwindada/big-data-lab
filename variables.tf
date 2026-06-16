# variables.tf
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "ruwinda"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "data-platform-lab"
}

variable "redshift_admin_password" {
  description = "Admin password for Redshift Serverless"
  type        = string
  sensitive   = true
  default     = "BigDataLab2026!"  # Change this!
}

variable "redshift_base_capacity" {
  description = "Redshift Serverless RPU capacity (8-512)"
  type        = number
  default     = 8
}

variable "glue_worker_type" {
  description = "Glue worker type (G.1X, G.2X, G.4X, G.8X)"
  type        = string
  default     = "G.1X"
}

variable "glue_number_of_workers" {
  description = "Number of Glue workers"
  type        = number
  default     = 2
}

variable "glue_timeout_minutes" {
  description = "Glue job timeout in minutes"
  type        = number
  default     = 20
}

variable "force_destroy_bucket" {
  description = "Force destroy S3 bucket even if not empty (lab only)"
  type        = bool
  default     = true
}