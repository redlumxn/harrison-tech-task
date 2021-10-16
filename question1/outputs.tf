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
