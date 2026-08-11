output "bucket_name" {
  value = aws_s3_bucket.app_storage.id
}

output "bucket_arn" {
  value = aws_s3_bucket.app_storage.arn
}
