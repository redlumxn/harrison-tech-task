terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.0.9"
}

provider "aws" {
  alias   = "harrisson"
  region  = local.region
  profile = local.harrison_profile
}

provider "aws" {
  region  = local.region
  profile = local.annalise_profile
}