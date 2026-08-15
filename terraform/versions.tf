terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }

  # Remote state — swap the bucket/table names for your own before running.
  # Using a remote backend is what makes this safe to run from CI.
  backend "s3" {
    bucket         = "REPLACE_ME-terraform-state"
    key            = "orders-api/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "REPLACE_ME-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "orders-api"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
