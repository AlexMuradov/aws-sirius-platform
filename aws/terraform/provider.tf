terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.65.0"
    }
  }
  backend "s3" {
      bucket = "observatory.cloud.states"
      key    = "sirius/terraform.tfstate"
      region = "us-east-1"
  }
}

provider "aws" {
  region     = var.region
}