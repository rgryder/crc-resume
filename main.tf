terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "remote" {
    organization = "gryder-io"
    workspaces {
      name = "crc-terraform"
    }
  }
}

# Configure the AWS Provider
provider "aws" {}

resource "aws_s3_bucket" "crc" {
  bucket = "rgrydercrc"
}

resource "aws_s3_bucket_acl" "crc" {
  bucket = aws_s3_bucket.crc.id
  acl    = "private"
}

resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.crc.id
  key    = "index.html"
  source = "index.html"
}

resource "aws_s3_object" "resetcss" {
  bucket = aws_s3_bucket.crc.id
  key    = "reset-fonts-grids.css"
  source = "reset-fonts-grids.css"
}

resource "aws_s3_object" "resumecss" {
  bucket = aws_s3_bucket.crc.id
  key    = "resume.css"
  source = "resume.css"
}

locals {
  s3_origin_id = "rgrydercrc.s3.us-east-1.amazonaws.com"
  resume_url = "resume.gryder.io"
}

data "aws_acm_certificate" "resume" {
  domain      = local.resume_url
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

resource "aws_cloudfront_cache_policy" "crc" {
  name        = "crc-policy"
  comment     = "Cache Policy for Cloud Resume"
  min_ttl     = 3600
  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.crc.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Cloud Resume Cloudfront Distribution"
  default_root_object = "index.html"

  aliases = [local.resume_url]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    cache_policy_id = aws_cloudfront_cache_policy.crc.id
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }
  
  viewer_certificate {
    acm_certificate_arn = data.aws_acm_certificate.resume.arn
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
