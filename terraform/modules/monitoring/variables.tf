variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "slack_webhook_url" {
  type      = string
  sensitive = true
}

variable "alb_arn_suffix" {
  type = string
}

variable "app_instance_ids" {
  type = list(string)
}

variable "db_instance_id" {
  type = string
}

variable "sns_email" {
  type = string
}