# ─── AMI Data Sources ─────────────────────────────────────────────────────────
data "aws_ami" "ubuntu_22" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "centos_9" {
  most_recent = true
  owners      = ["679593333241"] # CentOS official
  filter {
    name   = "name"
    values = ["CentOS Stream 9*x86_64*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─── User Data Templates ──────────────────────────────────────────────────────
locals {
  ubuntu_userdata = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y python3 python3-pip awscli
    # CloudWatch agent
    wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
    dpkg -i amazon-cloudwatch-agent.deb
    rm amazon-cloudwatch-agent.deb
    # SSM agent (for Session Manager as Bastion alternative)
    snap install amazon-ssm-agent --classic
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
  EOF

  centos_userdata = <<-EOF
    #!/bin/bash
    set -e
    dnf update -y
    dnf install -y python3 python3-pip awscli
    # CloudWatch agent
    rpm -Uvh https://s3.amazonaws.com/amazoncloudwatch-agent/centos/amd64/latest/amazon-cloudwatch-agent.rpm
    # SSM agent
    dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
  EOF
}

# ─── Application Server 1 ────────────────────────────────────────────────────
resource "aws_instance" "app_server_1" {
  ami                    = data.aws_ami.ubuntu_22.id
  instance_type          = var.app_instance_type
  subnet_id              = var.app_subnet_id
  vpc_security_group_ids = [var.app_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = var.app_instance_profile
  user_data              = base64encode(local.ubuntu_userdata)

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app-1"
    Role = "app-server"
  }
}

# ─── Application Server 2 ────────────────────────────────────────────────────
resource "aws_instance" "app_server_2" {
  ami                    = data.aws_ami.ubuntu_22.id
  instance_type          = var.app_instance_type
  subnet_id              = var.app_subnet_id
  vpc_security_group_ids = [var.app_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = var.app_instance_profile
  user_data              = base64encode(local.ubuntu_userdata)

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app-2"
    Role = "app-server"
  }
}

# ─── ALB Target Group Attachments ────────────────────────────────────────────
resource "aws_lb_target_group_attachment" "app_1" {
  target_group_arn = var.alb_target_group_arn
  target_id        = aws_instance.app_server_1.id
  port             = 3000
}

resource "aws_lb_target_group_attachment" "app_2" {
  target_group_arn = var.alb_target_group_arn
  target_id        = aws_instance.app_server_2.id
  port             = 3000
}

# ─── RabbitMQ Server ─────────────────────────────────────────────────────────
resource "aws_instance" "rabbitmq" {
  ami                    = data.aws_ami.ubuntu_22.id
  instance_type          = var.app_instance_type
  subnet_id              = var.app_subnet_id
  vpc_security_group_ids = [var.app_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = var.app_instance_profile
  user_data              = base64encode(local.ubuntu_userdata)

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rabbitmq"
    Role = "rabbitmq"
  }
}

# ─── Memcached Server ────────────────────────────────────────────────────────
resource "aws_instance" "memcached" {
  ami                    = data.aws_ami.ubuntu_22.id
  instance_type          = var.app_instance_type
  subnet_id              = var.app_subnet_id
  vpc_security_group_ids = [var.app_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = var.app_instance_profile
  user_data              = base64encode(local.ubuntu_userdata)

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-memcached"
    Role = "memcached"
  }
}

# ─── Bastion Host (public subnet) ────────────────────────────────────────────
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu_22.id
  instance_type               = "t3.micro"
  # subnet_id                   = var.tools_subnet_id
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.bastion_sg_id]
  key_name                    = var.key_name
  iam_instance_profile        = var.tools_instance_profile
  associate_public_ip_address = true
  user_data                   = base64encode(local.ubuntu_userdata)

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion"
    Role = "bastion"
  }
}

# ─── Jenkins Server ──────────────────────────────────────────────────────────
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.ubuntu_22.id
  instance_type          = var.tools_instance_type
  subnet_id              = var.tools_subnet_id
  vpc_security_group_ids = [var.tools_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = var.tools_instance_profile
  user_data              = base64encode(local.ubuntu_userdata)

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins"
    Role = "jenkins"
  }
}

# ─── MySQL Database Server ───────────────────────────────────────────────────
resource "aws_instance" "db" {
  ami                    = data.aws_ami.centos_9.id
  instance_type          = var.db_instance_type
  subnet_id              = var.data_subnet_id
  vpc_security_group_ids = [var.db_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = var.db_instance_profile
  user_data              = base64encode(local.centos_userdata)

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }

  # Separate EBS volume for MySQL data directory
  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_type           = "gp3"
    volume_size           = 50
    encrypted             = true
    delete_on_termination = false # Persist data on instance replacement
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-db"
    Role = "database"
  }
}
