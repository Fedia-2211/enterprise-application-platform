output "alb_sg_id"       { value = aws_security_group.alb.id }
output "app_sg_id"       { value = aws_security_group.app.id }
output "tools_sg_id"     { value = aws_security_group.tools.id }
output "db_sg_id"        { value = aws_security_group.db.id }
output "bastion_sg_id"   { value = aws_security_group.bastion.id }
output "rabbitmq_sg_id"  { value = aws_security_group.rabbitmq.id }
output "memcached_sg_id" { value = aws_security_group.memcached.id }
