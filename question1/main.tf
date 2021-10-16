resource "random_string" "random" {
  length  = 16
  special = false
  lower   = true
  upper   = false
}

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

#######################
# ANNALISE.AI RESOURCES
#######################
data "aws_caller_identity" "annalise" {
}

resource "aws_s3_bucket" "source" {
  bucket = "annalise-ai-data-${random_string.random.result}"
  acl    = "private"

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

  replication_configuration {
    role = aws_iam_role.replication_role.arn

    rules {
      id                               = "ReplicationRule"
      status                           = "Enabled"
      delete_marker_replication_status = "Enabled"

      destination {
        bucket        = aws_s3_bucket.destination.arn
        storage_class = "STANDARD"
        access_control_translation {
          owner = "Destination"
        }
        account_id = data.aws_caller_identity.harrison.account_id
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "source" {
  bucket                  = aws_s3_bucket.source.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "replication_role" {
  name = "iam-role-replication"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "replication_role_policy" {
  name = "iam-role-policy-replication"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.source.arn}"
      ]
    },
    {
      "Action": [
        "s3:GetObjectVersionForReplication",
        "s3:GetObjectVersionAcl",
        "s3:GetObjectVersionTagging"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.source.arn}/*"
      ]
    },
    {
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete",
        "s3:ReplicateTags",
        "s3:ObjectOwnerOverrideToBucketOwner"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.destination.arn}/*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "replication" {
  role       = aws_iam_role.replication_role.name
  policy_arn = aws_iam_policy.replication_role_policy.arn
}

# OUTPUTS

output "source_bucket" {
  value = aws_s3_bucket.source.id
}

output "destination_bucket" {
  value = aws_s3_bucket.destination.id
}

output "iam_role_in_source_account" {
  value = aws_iam_role.replication_role.arn
}
