terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
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
  
provider "cloudflare" {}

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
  content_type = "text/html"
}

resource "aws_s3_object" "favicon" {
  bucket = aws_s3_bucket.crc.id
  key    = "favicon.ico"
  source = "favicon.ico"
  content_type = "image/x-icon"
}

resource "aws_s3_object" "resetcss" {
  bucket = aws_s3_bucket.crc.id
  key    = "reset-fonts-grids.css"
  source = "reset-fonts-grids.css"
  content_type = "text/css"
}

resource "aws_s3_object" "resumecss" {
  bucket = aws_s3_bucket.crc.id
  key    = "resume.css"
  source = "resume.css"
  content_type = "text/css"
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

data "cloudflare_zones" "gryderio" {
  filter {
    name = "gryder.io"
  }
}
  
resource "cloudflare_record" "resume" {
  zone_id = data.cloudflare_zones.gryderio.zones[0].id
  name    = "resume"
  value   = aws_cloudfront_distribution.crc.domain_name
  type    = "CNAME"
  ttl     = 3600
}

resource "aws_cloudfront_distribution" "crc" {
  origin {
    domain_name              = aws_s3_bucket.crc.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.crc.cloudfront_access_identity_path
    }
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

resource "aws_cloudfront_origin_access_identity" "crc" {
  comment = "OAI for Cloud Resume"
}

data "aws_iam_policy_document" "crc" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.crc.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.crc.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "crc" {
  bucket = aws_s3_bucket.crc.id
  policy = data.aws_iam_policy_document.crc.json
}

resource "aws_s3_bucket_public_access_block" "crc" {
  bucket = aws_s3_bucket.crc.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
