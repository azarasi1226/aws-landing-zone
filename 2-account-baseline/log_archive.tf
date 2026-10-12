# 全アカウントのログ（Config、CloudTrail）を保管するS3バケットを、log-archiveアカウントに作成する
# バケット名に「log-archive」を含め、1-organization/security-ou/scp.tf のSCPで削除・設定変更から保護する

locals {
  log_archive_bucket_name  = "log-archive-${module.accounts.ids["log-archive"]}"
  organization_account_ids = values(module.accounts.ids)
}

resource "aws_s3_bucket" "log_archive" {
  provider = aws.log_archive

  bucket = local.log_archive_bucket_name

  lifecycle {
    # 削除や作り直しになる変更をplanの段階でエラーにして止める
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "log_archive" {
  provider = aws.log_archive

  bucket                  = aws_s3_bucket.log_archive.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ACLを無効にし、他のアカウントから書き込まれたログもバケットの所有者のものにする
resource "aws_s3_bucket_ownership_controls" "log_archive" {
  provider = aws.log_archive

  bucket = aws_s3_bucket.log_archive.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "log_archive" {
  provider = aws.log_archive

  bucket = aws_s3_bucket.log_archive.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive" {
  provider = aws.log_archive

  bucket = aws_s3_bucket.log_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# SCPでログの削除は誰にも許可していないため、古いログはライフサイクルルールで削除する
resource "aws_s3_bucket_lifecycle_configuration" "log_archive" {
  provider = aws.log_archive

  bucket = aws_s3_bucket.log_archive.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.log_archive]
}

resource "aws_s3_bucket_policy" "log_archive" {
  provider = aws.log_archive

  bucket = aws_s3_bucket.log_archive.id
  policy = data.aws_iam_policy_document.log_archive_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.log_archive]
}

# 各サービスからの書き込み・読み取りの許可は、config.tf と cloudtrail.tf にある
data "aws_iam_policy_document" "log_archive_bucket" {
  source_policy_documents = [
    data.aws_iam_policy_document.config_bucket.json,
    data.aws_iam_policy_document.cloudtrail_bucket.json,
  ]

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.log_archive.arn, "${aws_s3_bucket.log_archive.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}
