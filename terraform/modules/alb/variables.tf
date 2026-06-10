variable "project_name"          { type = string }
variable "environment"            { type = string }
variable "vpc_id"                 { type = string }
variable "public_subnet_id"       { type = string }
variable "alb_security_group_id"  { type = string }
variable "certificate_arn"        { type = string }
variable "s3_logs_bucket"         { type = string }
variable "health_check_path"      { type = string }
variable "domain_name" {
  type    = string
  default = ""
}

variable "route53_zone_name" {
  type    = string
  default = ""
}
variable "public_subnet_2_id" { type = string }