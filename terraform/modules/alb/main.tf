resource "aws_lb" "main" {
  name               = "eap-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = [var.public_subnet_id, var.public_subnet_2_id]

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true
  idle_timeout                     = 60

  access_logs {
    bucket  = var.s3_logs_bucket
    prefix  = "alb-logs"
    enabled = true
  }

  tags = { Name = "${var.project_name}-${var.environment}-alb" }
}

# ─── Target Group ─────────────────────────────────────────────────────────────
resource "aws_lb_target_group" "app" {
  name        = "eap-${var.environment}-tg-app"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
  path                = "/api/healthz"
  healthy_threshold   = 2
  unhealthy_threshold = 3
  interval            = 30
 }
  

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = false # Session handled by Memcached — no sticky sessions needed
  }

  tags = { Name = "${var.project_name}-${var.environment}-tg-app" }
}

# ─── HTTPS Listener ───────────────────────────────────────────────────────────
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ─── HTTP → HTTPS Redirect ────────────────────────────────────────────────────
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ─── Route 53 Alias Record ────────────────────────────────────────────────────
data "aws_route53_zone" "main" {
  name         = var.route53_zone_name
  private_zone = false
}

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
