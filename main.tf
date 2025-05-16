terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

module "staging" {
  source = "./staging"
  providers = {
    aws = aws.staging
  }
}

module "production" {
  source = "./production"
  providers = {
    aws = aws.production
  }
}
