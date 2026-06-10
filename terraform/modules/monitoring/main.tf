locals {
  alarm_prefix = "${var.project_name}-${var.environment}"
}

# ─── SNS Topic for Alarms ─────────────────────────────────────────────────────
resource "aws_sns_topic" "alarms" {
  name = "${local.alarm_prefix}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.sns_email
}

# ─── Lambda for Slack Notifications ─────────────────────────────────────────
resource "aws_iam_role" "lambda_sns" {
  name = "${local.alarm_prefix}-lambda-slack-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_sns.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "slack_notifier" {
  type        = "zip"
  output_path = "${path.module}/slack_notifier.zip"
  source {
    content  = <<-PYTHON
import json, urllib.request, os

def handler(event, context):
    webhook = os.environ['SLACK_WEBHOOK_URL']
    for record in event.get('Records', []):
        sns_msg = json.loads(record['Sns']['Message'])
        alarm   = sns_msg.get('AlarmName', 'Unknown')
        state   = sns_msg.get('NewStateValue', 'UNKNOWN')
        reason  = sns_msg.get('NewStateReason', '')
        color   = '#FF0000' if state == 'ALARM' else '#00FF00'
        payload = {
            'attachments': [{
                'color': color,
                'title': f'CloudWatch Alarm: {alarm}',
                'text': f'State: *{state}*\nReason: {reason}',
                'footer': 'AWS CloudWatch'
            }]
        }
        req = urllib.request.Request(
            webhook,
            data=json.dumps(payload).encode(),
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        urllib.request.urlopen(req)
    return {'statusCode': 200}
    PYTHON
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "slack_notifier" {
  filename         = data.archive_file.slack_notifier.output_path
  function_name    = "${local.alarm_prefix}-slack-notifier"
  role             = aws_iam_role.lambda_sns.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.slack_notifier.output_base64sha256

  environment {
    variables = { SLACK_WEBHOOK_URL = var.slack_webhook_url }
  }
}

resource "aws_sns_topic_subscription" "lambda_slack" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier.arn
}

resource "aws_lambda_permission" "sns" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alarms.arn
}

# ─── CloudWatch Alarms — EC2 ──────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "cpu_high_app1" {
  alarm_name          = "${local.alarm_prefix}-app1-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "App server 1 CPU > 80% for 10 minutes"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions          = { InstanceId = var.app_instance_ids[0] }
}

resource "aws_cloudwatch_metric_alarm" "cpu_high_app2" {
  alarm_name          = "${local.alarm_prefix}-app2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "App server 2 CPU > 80% for 10 minutes"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions          = { InstanceId = var.app_instance_ids[1] }
}

resource "aws_cloudwatch_metric_alarm" "cpu_high_db" {
  alarm_name          = "${local.alarm_prefix}-db-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "DB server CPU > 70% for 10 minutes"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions          = { InstanceId = var.db_instance_id }
}

# ─── ALB Alarms ───────────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.alarm_prefix}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "More than 10 5xx errors per minute on ALB"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
}

resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  alarm_name          = "${local.alarm_prefix}-alb-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  extended_statistic  = "p95"
  threshold           = 2
  alarm_description   = "p95 response time > 2 seconds for 3 consecutive minutes"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
}

resource "aws_cloudwatch_metric_alarm" "healthy_hosts" {
  alarm_name          = "${local.alarm_prefix}-unhealthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "No healthy hosts in ALB target group"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
}

# ─── CloudWatch Log Groups ────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "app" {
  name              = "/app/${var.project_name}/${var.environment}/gitea"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/app/${var.project_name}/${var.environment}/nginx"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "mysql" {
  name              = "/app/${var.project_name}/${var.environment}/mysql"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "auth" {
  name              = "/app/${var.project_name}/${var.environment}/auth"
  retention_in_days = 90
}

resource "aws_cloudwatch_log_group" "jenkins" {
  name              = "/app/${var.project_name}/${var.environment}/jenkins"
  retention_in_days = 30
}

# ─── CloudWatch Dashboard ─────────────────────────────────────────────────────
# resource "aws_cloudwatch_dashboard" "main" {
#   dashboard_name = "${local.alarm_prefix}-overview"
#   dashboard_body = jsonencode({
#     widgets = [
#       {
#         type   = "metric"
#         x      = 0
#         y      = 0
#         width  = 12
#         height = 6
#         properties = {
#           title   = "App Servers — CPU Utilization"
#           region  = var.aws_region
#           period  = 300
#           stat    = "Average"
#           view    = "timeSeries"
#           stacked = false
#           metrics = [
#             ["AWS/EC2", "CPUUtilization", "InstanceId", var.app_instance_ids[0], { label = "App Server 1" }],
#             ["AWS/EC2", "CPUUtilization", "InstanceId", var.app_instance_ids[1], { label = "App Server 2" }],
#             ["AWS/EC2", "CPUUtilization", "InstanceId", var.db_instance_id,      { label = "DB Server" }]
#           ]
#         }
#       },
#       {
#         type   = "metric"
#         x      = 12
#         y      = 0
#         width  = 12
#         height = 6
#         properties = {
#           title   = "ALB — Request Count & 5xx Errors"
#           region  = var.aws_region
#           period  = 60
#           stat    = "Sum"
#           view    = "timeSeries"
#           stacked = false
#           metrics = [
#             ["AWS/ApplicationELB", "RequestCount",             "LoadBalancer", var.alb_arn_suffix],
#             ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count","LoadBalancer", var.alb_arn_suffix],
#             ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count","LoadBalancer", var.alb_arn_suffix]
#           ]
#         }
#       },
#       {
#         type   = "metric"
#         x      = 0
#         y      = 6
#         width  = 12
#         height = 6
#         properties = {
#           title   = "ALB — Target Response Time (p95)"
#           region  = var.aws_region
#           period  = 60
#           stat    = "p95"
#           view    = "timeSeries"
#           stacked = false
#           metrics = [
#             ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix]
#           ]
#         }
#       },
#       {
#         type   = "metric"
#         x      = 12
#         y      = 6
#         width  = 12
#         height = 6
#         properties = {
#           title   = "ALB — Healthy Host Count"
#           region  = var.aws_region
#           period  = 60
#           stat    = "Minimum"
#           view    = "timeSeries"
#           stacked = false
#           metrics = [
#             ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix]
#           ]
#         }
#       }
#     ]
#   })
# }