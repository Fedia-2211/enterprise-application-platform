# ─── ALB Security Group ───────────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-sg-alb"
  description = "ALB: allow HTTPS from internet, HTTP redirect only"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP from internet (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-sg-alb" }
}

# ─── App Server Security Group ────────────────────────────────────────────────
resource "aws_security_group" "app" {
  name        = "${var.project_name}-${var.environment}-sg-app"
  description = "App servers: HTTP from ALB only, SSH from Bastion only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App port from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    description     = "HTTP from ALB (Nginx health check)"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    description     = "SSH from Bastion only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  ingress {
    description     = "SSH from Jenkins for deployments"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.tools.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-sg-app" }
}

# ─── Tools Security Group (Jenkins + Bastion collocated) ──────────────────────
# IMPORTANT: Description must stay original to avoid replacement (manual dependencies exist)
resource "aws_security_group" "tools" {
  name        = "${var.project_name}-${var.environment}-sg-tools"
  description = "Tools subnet: Jenkins port from VPC, SSH intra-tools"
  vpc_id      = var.vpc_id

  ingress {
    description = "Jenkins from ALB"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }
  ingress {
    description     = "SSH from Bastion to Jenkins"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-sg-tools" }
}

# ─── Bastion Security Group ───────────────────────────────────────────────────
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-sg-bastion"
  description = "Bastion: SSH from your IP only"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from admin IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-${var.environment}-sg-bastion" }
}

# ─── RabbitMQ Security Group ──────────────────────────────────────────────────
resource "aws_security_group" "rabbitmq" {
  name        = "${var.project_name}-${var.environment}-sg-rabbitmq"
  description = "RabbitMQ: AMQP and management from app subnet only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "AMQP from app servers"
    from_port       = 5672
    to_port         = 5672
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  ingress {
    description     = "Management UI from Bastion"
    from_port       = 15672
    to_port         = 15672
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-${var.environment}-sg-rabbitmq" }
}

# ─── Memcached Security Group ─────────────────────────────────────────────────
resource "aws_security_group" "memcached" {
  name        = "${var.project_name}-${var.environment}-sg-memcached"
  description = "Memcached: port 11211 from app servers only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Memcached from app servers"
    from_port       = 11211
    to_port         = 11211
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-${var.environment}-sg-memcached" }
}

# ─── Database Security Group ──────────────────────────────────────────────────
resource "aws_security_group" "db" {
  name        = "${var.project_name}-${var.environment}-sg-db"
  description = "DB: MySQL 3306 from app servers only, SSH from Bastion"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from app servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-sg-db" }
}