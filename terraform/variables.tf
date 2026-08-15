variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (staging | production)"
  type        = string
  default     = "staging"
}

variable "app_name" {
  description = "Short name used to prefix resources"
  type        = string
  default     = "orders-api"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3000
}

variable "image_tag" {
  description = "Docker image tag to deploy (set by CI to the git SHA)"
  type        = string
  default     = "latest"
}

variable "desired_count" {
  description = "Number of Fargate tasks to run"
  type        = number
  default     = 2
}

variable "cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate task memory (MB)"
  type        = number
  default     = 512
}

variable "vpc_cidr" {
  description = "CIDR block for the demo VPC"
  type        = string
  default     = "10.42.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across"
  type        = number
  default     = 2
}

variable "alarm_cpu_threshold" {
  description = "CPU utilization threshold percent for CloudWatch alarm"
  type        = number
  default     = 80
}

variable "alarm_memory_threshold" {
  description = "Memory utilization threshold percent for CloudWatch alarm"
  type        = number
  default     = 85
}

variable "alarm_5xx_threshold" {
  description = "5xx error count threshold per 5 minutes for CloudWatch alarm"
  type        = number
  default     = 5
}

variable "alarm_actions_enabled" {
  description = "Whether CloudWatch alarms should trigger actions (SNS, etc.)"
  type        = bool
  default     = false
}

variable "sns_alarm_email" {
  description = "Email address to subscribe to the alarms SNS topic (leave empty to skip)"
  type        = string
  default     = ""
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "cdn_enabled" {
  description = "Whether to provision a CloudFront CDN in front of the ALB"
  type        = bool
  default     = true
}

variable "cdn_price_class" {
  description = "CloudFront price class (PriceClass_100 | PriceClass_200 | PriceClass_All)"
  type        = string
  default     = "PriceClass_100"
}

variable "cdn_default_ttl" {
  description = "Default TTL in seconds for CloudFront cache"
  type        = number
  default     = 0
}

variable "cdn_min_ttl" {
  description = "Minimum TTL in seconds for CloudFront cache"
  type        = number
  default     = 0
}

variable "cdn_max_ttl" {
  description = "Maximum TTL in seconds for CloudFront cache"
  type        = number
  default     = 3600
}

variable "cdn_allowed_http_methods" {
  description = "Allowed HTTP methods for CloudFront"
  type        = list(string)
  default     = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
}

variable "cdn_cached_methods" {
  description = "HTTP methods that CloudFront should cache"
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "cdn_forward_headers" {
  description = "Headers CloudFront forwards to the origin (use * for all)"
  type        = list(string)
  default     = ["*"]
}

variable "cdn_forward_cookies" {
  description = "Cookies CloudFront forwards to the origin (all | none | whitelist)"
  type        = string
  default     = "all"
}

variable "cdn_forward_query_strings" {
  description = "Whether CloudFront forwards query strings to the origin"
  type        = bool
  default     = true
}

variable "cdn_acm_certificate_arn" {
  description = "ACM certificate ARN for custom HTTPS (must be in us-east-1). Leave empty to use the default CloudFront *.cloudfront.net cert on HTTP only."
  type        = string
  default     = ""
}

variable "cdn_custom_domain" {
  description = "Alternate domain name (CNAME) for the CloudFront distribution (e.g. api.example.com). Leave empty to skip."
  type        = string
  default     = ""
}
