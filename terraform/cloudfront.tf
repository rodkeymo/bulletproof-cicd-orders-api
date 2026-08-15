locals {
  cdn_viewer_protocol_allowed = var.cdn_acm_certificate_arn != "" ? "https-only" : "allow-all"

  use_custom_ssl = var.cdn_acm_certificate_arn != "" && var.cdn_custom_domain != ""

  cdn_aliases = local.use_custom_ssl ? [var.cdn_custom_domain] : []
}

resource "aws_cloudfront_origin_access_control" "alb_default" {
  count = var.cdn_enabled ? 1 : 0

  name                              = "${var.app_name}-alb-oac"
  description                       = "OAC for ${var.app_name} ALB origin"
  origin_access_control_origin_type = "alb"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_cache_policy" "api_default" {
  count = var.cdn_enabled ? 1 : 0

  name        = "${var.app_name}-api-cache"
  comment     = "Default cache policy for ${var.app_name} — by default pass-through, tune via TTL vars"
  default_ttl = var.cdn_default_ttl
  max_ttl     = var.cdn_max_ttl
  min_ttl     = var.cdn_min_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    cookies_config {
      cookie_behavior = var.cdn_forward_cookies
    }

    headers_config {
      header_behavior = contains(var.cdn_forward_headers, "*") ? "allViewer" : "whitelist"
      headers {
        items = contains(var.cdn_forward_headers, "*") ? [] : var.cdn_forward_headers
      }
    }

    query_strings_config {
      query_string_behavior = var.cdn_forward_query_strings ? "all" : "none"
    }
  }
}

resource "aws_cloudfront_origin_request_policy" "api_forward_all" {
  count = var.cdn_enabled ? 1 : 0

  name    = "${var.app_name}-api-forward-all"
  comment = "Forward all viewer headers, cookies, and query strings to the ALB origin"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "allViewerAndWhitelistCloudFront"
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

resource "aws_cloudfront_response_headers_policy" "security_headers" {
  count = var.cdn_enabled ? 1 : 0

  name    = "${var.app_name}-security-headers"
  comment = "Standard security headers for the API"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      override                   = true
      preload                    = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    xss_protection {
      mode_block = true
      override   = true
      protection = true
    }
  }
}

resource "aws_cloudfront_distribution" "api" {
  count = var.cdn_enabled ? 1 : 0

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.app_name} CDN → ALB origin"
  default_root_object = ""
  price_class         = var.cdn_price_class
  aliases             = local.cdn_aliases

  viewer_certificate {
    acm_certificate_arn            = local.use_custom_ssl ? var.cdn_acm_certificate_arn : null
    cloudfront_default_certificate = local.use_custom_ssl ? false : true
    minimum_protocol_version       = local.use_custom_ssl ? "TLSv1.2_2021" : "TLSv1"
    ssl_support_method             = local.use_custom_ssl ? "sni-only" : null
  }

  origin {
    domain_name              = aws_lb.main.dns_name
    origin_id                = "${var.app_name}-alb-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.alb_default[0].id

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 60
      origin_keepalive_timeout = 5
    }

    custom_header {
      name  = "X-Forwarded-Host"
      value = aws_lb.main.dns_name
    }
  }

  default_cache_behavior {
    target_origin_id       = "${var.app_name}-alb-origin"
    allowed_methods        = var.cdn_allowed_http_methods
    cached_methods         = var.cdn_cached_methods
    viewer_protocol_policy = local.cdn_viewer_protocol_allowed

    cache_policy_id            = aws_cloudfront_cache_policy.api_default[0].id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_forward_all[0].id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers[0].id

    compress         = true
    smooth_streaming = false
  }

  ordered_cache_behavior {
    path_pattern               = "/health"
    target_origin_id           = "${var.app_name}-alb-origin"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    viewer_protocol_policy     = local.cdn_viewer_protocol_allowed
    compress                   = true
    default_ttl                = 0
    max_ttl                    = 0
    min_ttl                    = 0
    cache_policy_id            = aws_cloudfront_cache_policy.api_default[0].id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_forward_all[0].id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers[0].id
  }

  ordered_cache_behavior {
    path_pattern               = "/ready"
    target_origin_id           = "${var.app_name}-alb-origin"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    viewer_protocol_policy     = local.cdn_viewer_protocol_allowed
    compress                   = true
    default_ttl                = 0
    max_ttl                    = 0
    min_ttl                    = 0
    cache_policy_id            = aws_cloudfront_cache_policy.api_default[0].id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_forward_all[0].id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers[0].id
  }

  ordered_cache_behavior {
    path_pattern               = "/orders*"
    target_origin_id           = "${var.app_name}-alb-origin"
    allowed_methods            = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods             = ["GET", "HEAD"]
    viewer_protocol_policy     = local.cdn_viewer_protocol_allowed
    compress                   = true
    cache_policy_id            = aws_cloudfront_cache_policy.api_default[0].id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_forward_all[0].id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers[0].id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  custom_error_response {
    error_code            = 404
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 500
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 502
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 503
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 504
    error_caching_min_ttl = 10
  }

  tags = {
    Name = "${var.app_name}-cdn"
  }
}

resource "aws_security_group" "alb_cdn_only" {
  count = var.cdn_enabled ? 1 : 0

  name        = "${var.app_name}-alb-cdn-only-sg"
  description = "ALB SG — allow inbound HTTP from CloudFront managed prefix list only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from CloudFront (managed prefix list)"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_prefix_list.cloudfront[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_prefix_list" "cloudfront" {
  count = var.cdn_enabled ? 1 : 0
  name  = "com.amazonaws.global.cloudfront.origin-facing"
}
