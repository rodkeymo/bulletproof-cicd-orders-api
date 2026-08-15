locals {
  alarm_actions = var.alarm_actions_enabled && var.sns_alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
  ok_actions    = var.alarm_actions_enabled && var.sns_alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

resource "aws_sns_topic" "alarms" {
  count = var.sns_alarm_email != "" ? 1 : 0
  name  = "${var.app_name}-alarms"
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count     = var.sns_alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.sns_alarm_email
}

resource "aws_sns_topic_policy" "cloudwatch_publish" {
  count  = var.sns_alarm_email != "" ? 1 : 0
  arn    = aws_sns_topic.alarms[0].arn
  policy = data.aws_iam_policy_document.cloudwatch_sns[0].json
}

data "aws_iam_policy_document" "cloudwatch_sns" {
  count = var.sns_alarm_email != "" ? 1 : 0

  statement {
    actions = ["SNS:Publish"]
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    resources = [aws_sns_topic.alarms[0].arn]
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  name           = "${var.app_name}-app-errors"
  pattern        = "ERROR"
  log_group_name = aws_cloudwatch_log_group.app.name

  metric_transformation {
    name      = "${var.app_name}-app-errors"
    namespace = "${var.app_name}/metrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "app_warnings" {
  name           = "${var.app_name}-app-warnings"
  pattern        = "WARN"
  log_group_name = aws_cloudwatch_log_group.app.name

  metric_transformation {
    name      = "${var.app_name}-app-warnings"
    namespace = "${var.app_name}/metrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.app_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.alarm_cpu_threshold
  alarm_description   = "ECS service CPU utilization above ${var.alarm_cpu_threshold}% for 2 consecutive 5-min periods"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.app_name}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "ECS/ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = var.alarm_memory_threshold
  alarm_description   = "ECS service memory utilization above ${var.alarm_memory_threshold}% for 2 consecutive 5-min periods"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_high" {
  alarm_name          = "${var.app_name}-alb-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alarm_5xx_threshold
  alarm_description   = "ALB 5xx responses exceed ${var.alarm_5xx_threshold} in a 5-min window"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_4xx_rate" {
  alarm_name          = "${var.app_name}-alb-4xx-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "ALB 4xx responses exceed 50 in 5-min window (potential misuse or client errors)"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "app_error_rate" {
  alarm_name          = "${var.app_name}-log-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "${var.app_name}-app-errors"
  namespace           = "${var.app_name}/metrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Application ERROR log lines exceed 10 in a 5-min window"

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "ecs_unhealthy_hosts" {
  alarm_name          = "${var.app_name}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_description   = "ALB reports any unhealthy target hosts for 2 consecutive 1-min periods"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "autoscaling_actions" {
  alarm_name          = "${var.app_name}-autoscaling-often"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = 3600
  statistic           = "Maximum"
  threshold           = var.desired_count * 2
  alarm_description   = "ECS running task count exceeds ${var.desired_count * 2} within the last hour — sustained traffic spike or scaling thrashing"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.app_name}-overview"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.app.name, { id = "cpu", label = "CPU %", stat = "Average" }],
            [".", "MemoryUtilization", ".", ".", ".", ".", { id = "mem", namespace = "ECS/ContainerInsights", label = "Memory %", stat = "Average" }]
          ]
          period  = 60
          title   = "ECS Service — CPU & Memory"
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix, { id = "req", label = "Requests", stat = "Sum" }],
            [".", "HTTPCode_Target_2XX_Count", ".", ".", { id = "2xx", label = "2xx", stat = "Sum" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", { id = "4xx", label = "4xx", stat = "Sum" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { id = "5xx", label = "5xx", stat = "Sum" }]
          ]
          period  = 60
          title   = "ALB — Request Volume & HTTP Codes"
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix, { id = "lat", label = "Avg Latency (s)", stat = "Average", yAxis = "left" }],
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.main.arn_suffix, "TargetGroup", aws_lb_target_group.app.arn_suffix, { id = "hh", label = "Healthy Hosts", stat = "Maximum", yAxis = "right" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { id = "uh", label = "Unhealthy Hosts", stat = "Maximum", yAxis = "right" }]
          ]
          period  = 60
          title   = "ALB — Latency & Target Health"
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          yAxis = {
            left  = { label = "Seconds" }
            right = { label = "Host Count", min = 0 }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["${var.app_name}/metrics", "${var.app_name}-app-errors", { id = "errors", label = "ERROR lines", stat = "Sum" }],
            ["${var.app_name}/metrics", "${var.app_name}-app-warnings", { id = "warns", label = "WARN lines", stat = "Sum" }]
          ]
          period  = 300
          title   = "Application — Errors & Warnings (from logs)"
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "DesiredTaskCount", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.app.name, { id = "desired", label = "Desired Tasks", stat = "Maximum" }],
            [".", "RunningTaskCount", ".", ".", ".", ".", { id = "running", label = "Running Tasks", stat = "Maximum" }],
            [".", "PendingTaskCount", ".", ".", ".", ".", { id = "pending", label = "Pending Tasks", stat = "Maximum" }]
          ]
          period  = 60
          title   = "ECS — Task Count (Auto-Scaling)"
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.app.name, { id = "cpu", label = "CPU %", stat = "Maximum" }],
            ["ECS/ContainerInsights", "MemoryUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.app.name, { id = "mem", label = "Memory %", stat = "Maximum" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.main.arn_suffix, { id = "5xx", label = "5XX Sum", stat = "Sum" }]
          ]
          annotations = {
            horizontal = [
              { label = "CPU threshold", value = var.alarm_cpu_threshold },
              { label = "Memory threshold", value = var.alarm_memory_threshold },
              { label = "5XX threshold/5m", value = var.alarm_5xx_threshold }
            ]
            alarms = [
              aws_cloudwatch_metric_alarm.ecs_cpu_high.arn,
              aws_cloudwatch_metric_alarm.alb_5xx_high.arn,
              aws_cloudwatch_metric_alarm.ecs_unhealthy_hosts.arn
            ]
          }
          period  = 300
          title   = "Key Metrics vs Alarm Thresholds"
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          yAxis = {
            left = { min = 0 }
          }
        }
      }
    ]
  })
}
