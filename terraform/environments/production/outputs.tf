output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Hosted Zone ID of the ALB (for Route 53 alias record)"
  value       = module.alb.alb_zone_id
}

output "app_server_1_private_ip" {
  description = "Private IP of application server 1"
  value       = module.compute.app_server_1_private_ip
}

output "app_server_2_private_ip" {
  description = "Private IP of application server 2"
  value       = module.compute.app_server_2_private_ip
}

output "bastion_public_ip" {
  description = "Public IP of the Bastion host"
  value       = module.compute.bastion_public_ip
}

output "jenkins_private_ip" {
  description = "Private IP of Jenkins server"
  value       = module.compute.jenkins_private_ip
}

output "db_private_ip" {
  description = "Private IP of the MySQL database server"
  value       = module.compute.db_private_ip
}

output "rabbitmq_private_ip" {
  description = "Private IP of the RabbitMQ server"
  value       = module.compute.rabbitmq_private_ip
}

output "memcached_private_ip" {
  description = "Private IP of the Memcached server"
  value       = module.compute.memcached_private_ip
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for backups and artifacts"
  value       = module.s3.bucket_id
}

# output "cloudwatch_dashboard_url" {
#   description = "URL to the CloudWatch dashboard"
#   value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.monitoring.dashboard_name}"
# }
