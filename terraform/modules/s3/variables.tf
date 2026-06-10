terraform {
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

variable "project_name" { type = string }
variable "environment"  { type = string }
