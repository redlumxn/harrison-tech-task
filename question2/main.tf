terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.62.0"
    }
  }

  required_version = ">= 1.0.9"
}

variable "object_count" {
  type = number
  default = 1750
  description = "Number of objects to create in the bucket"
}

provider "aws" {
  profile = "redlumxn"
  region  = "ap-southeast-2"
  default_tags {
    tags = {
      Environment = "Harrison-ai"
      Candidate   = "Rodrigo"
    }
  }
}

resource "aws_sqs_queue" "question_2_queue" {
  name                        = "question2-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = false
  deduplication_scope         = "queue"

  tags = {
    Question = "2"
  }
}

resource "aws_s3_bucket" "question_2_bucket" {
  bucket = "question-2-bucket${random_string.random.result}"
  acl    = "private"

  tags = {
    Question = "2"
  }
}

resource "random_string" "random" {
  length           = 16
  special          = false
  lower = true
  upper = false
#   override_special = "/@£$"
}

resource "aws_s3_bucket_object" "object" {
  count   = var.object_count
  bucket  = aws_s3_bucket.question_2_bucket.id
  key     = "${sha256(uuid())}.ext"
  content = uuid()
  storage_class = "ONEZONE_IA"

}

output "bucket_name" {
  value = aws_s3_bucket.question_2_bucket.id
}

output "queue_url" {
  value = aws_sqs_queue.question_2_queue.url
}