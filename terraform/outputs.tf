output "alb_dns_name" {
  description = "Public URL of the load balancer (use CDN URL instead if cdn_enabled=true)"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "ECR repo URL the CI pipeline pushes images to"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "cdn_enabled" {
  description = "Whether a CloudFront CDN was provisioned"
  value       = var.cdn_enabled
}

output "cdn_distribution_id" {
  description = "CloudFront distribution ID (if cdn_enabled=true)"
  value       = var.cdn_enabled ? aws_cloudfront_distribution.api[0].id : null
}

output "cdn_url" {
  description = "Public URL of the CloudFront CDN (if cdn_enabled=true). This is the entrypoint users should hit."
  value       = var.cdn_enabled ? "https://${aws_cloudfront_distribution.api[0].domain_name}" : null
}

output "cdn_domain_name" {
  description = "Domain name of the CloudFront distribution (d123....cloudfront.net)"
  value       = var.cdn_enabled ? aws_cloudfront_distribution.api[0].domain_name : null
}

output "cdn_custom_domain" {
  description = "Custom CNAME attached to CDN (if configured)"
  value       = var.cdn_custom_domain != "" ? var.cdn_custom_domain : null
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group name for the ECS service"
  value       = aws_cloudwatch_log_group.app.name
}

output "cloudwatch_dashboard_url" {
  description = "Console URL to the CloudWatch dashboard for this service"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch overview dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "sns_alarm_topic_arn" {
  description = "ARN of the SNS topic that alarm actions publish to (if sns_alarm_email set)"
  value       = var.sns_alarm_email != "" ? aws_sns_topic.alarms[0].arn : null
}

output "alarm_arns" {
  description = "Map of all created CloudWatch alarm ARNs by name"
  value = {
    ecs_cpu_high      = aws_cloudwatch_metric_alarm.ecs_cpu_high.arn
    ecs_memory_high   = aws_cloudwatch_metric_alarm.ecs_memory_high.arn
    alb_5xx_high      = aws_cloudwatch_metric_alarm.alb_5xx_high.arn
    alb_4xx_rate      = aws_cloudwatch_metric_alarm.alb_4xx_rate.arn
    app_error_rate    = aws_cloudwatch_metric_alarm.app_error_rate.arn
    unhealthy_hosts   = aws_cloudwatch_metric_alarm.ecs_unhealthy_hosts.arn
    autoscaling_often = aws_cloudwatch_metric_alarm.autoscaling_actions.arn
  }
}
