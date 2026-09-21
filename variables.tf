variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either dev or prod."
  }
}

variable "aws_region" {
  type = string
}

variable "secondary_region" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "instance_count" {
  type = number
}

variable "project_name" {
  type = string
}

variable "owner" {
  type = string
}

variable "excluded_azs" {
  type    = list(string)
  default = []
}