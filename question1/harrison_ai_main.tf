#######################
# HARRISON.AI RESOURCES
#######################
data "aws_caller_identity" "harrison" {
  provider = aws.harrisson
}

resource "aws_s3_bucket" "destination" {
  provider = aws.harrisson
  bucket   = "harrison-ai-landing-${random_string.random.result}"
  acl      = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "destination" {
  provider                = aws.harrisson
  bucket                  = aws_s3_bucket.destination.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cross_account_policy" {
  provider = aws.harrisson
  bucket   = aws_s3_bucket.destination.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Set permissions for objects"
        Effect = "Allow"
        Principal = {
          "AWS" : aws_iam_role.replication_role.arn
        }
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete"
        ]
        Resource = [
          "${aws_s3_bucket.destination.arn}/*",
        ]
      },
      {
        Sid    = "Set permissions on bucket"
        Effect = "Allow"
        Principal = {
          "AWS" : aws_iam_role.replication_role.arn
        }
        Action = [
          "s3:List*",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning"
        ]
        Resource = [
          aws_s3_bucket.destination.arn,
        ]
      },
      {
        Sid    = "Change replica ownership"
        Effect = "Allow"
        Principal = {
          "AWS" : data.aws_caller_identity.annalise.account_id
        }
        Action = [
          "s3:ObjectOwnerOverrideToBucketOwner"
        ]
        Resource = [
          "${aws_s3_bucket.destination.arn}/*",
        ]
      }
    ]
  })
}