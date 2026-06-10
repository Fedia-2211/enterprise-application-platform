variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "enterprise-application-platform"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "owner" {
  description = "Owner tag value for all resources"
  type        = string
  default     = "firdavs"
}

# ─── Network ─────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for the public subnet (ALB, NAT GW, Nginx)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "app_subnet_cidr" {
  description = "CIDR for private app subnet (app servers, RabbitMQ, Memcached)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "tools_subnet_cidr" {
  description = "CIDR for private tools subnet (Jenkins, Bastion)"
  type        = string
  default     = "10.0.3.0/24"
}

variable "data_subnet_cidr" {
  description = "CIDR for private data subnet (MySQL)"
  type        = string
  default     = "10.0.4.0/24"
}

variable "public_subnet_cidr_2" {
  description = "CIDR for second public subnet (AZ-b) — required for ALB"
  type        = string
  default     = "10.0.11.0/24"
}

variable "availability_zone" {
  description = "Primary availability zone"
  type        = string
  default     = "us-east-1a"
}

# ─── Security ────────────────────────────────────────────────────────────────
variable "your_ip_cidr" {
  description = "Your home/office IP in CIDR notation for Bastion SSH access"
  type        = string
  sensitive   = true
}

variable "bastion_ip" {
  description = "Private IP of the Bastion host (used in security group rules)"
  type        = string
  default     = "10.0.3.10"
}

variable "key_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
}

# ─── Compute ─────────────────────────────────────────────────────────────────
variable "app_instance_type" {
  description = "EC2 instance type for application servers"
  type        = string
  default     = "t3.small"
}

variable "db_instance_type" {
  description = "EC2 instance type for database server"
  type        = string
  default     = "t3.small"
}

variable "tools_instance_type" {
  description = "EC2 instance type for Jenkins and Bastion"
  type        = string
  default     = "c7i-flex.large"
}

# ─── DNS + TLS ───────────────────────────────────────────────────────────────
variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS on the ALB"
  type        = string
}

variable "domain_name" {
  description = "Your domain name (e.g. enterprise-application-platform.yourdomain.com)"
  type        = string
}

variable "health_check_path" {
  description = "HTTP path for ALB health checks"
  type        = string
  default     = "/-/health"
}

# ─── Notifications ───────────────────────────────────────────────────────────
variable "slack_webhook_url" {
  description = "Slack Incoming Webhook URL for CloudWatch alarm notifications"
  type        = string
  sensitive   = true
}

variable "sns_email" {
  description = "Email address for SNS alarm notifications"
  type        = string
}
