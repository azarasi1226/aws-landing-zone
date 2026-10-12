output "log_archive_bucket_name" {
  description = "全アカウントのログを保管するS3バケットの名前"
  value       = aws_s3_bucket.log_archive.bucket
}
