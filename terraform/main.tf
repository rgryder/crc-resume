terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
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
