# ------------------------------------------------------------
# レコーダー：全アカウント・全リージョンで設定を記録し、log-archiveのバケットに送る
# managementアカウントの分はデフォルトのproviderで作成する
# ------------------------------------------------------------

module "config_management" {
  source = "./modules/config-recorder"

  regions                = var.regions
  global_resource_region = var.region
  bucket_name            = aws_s3_bucket.log_archive.bucket

  # バケットポリシーで書き込みを許可してから、配信先に設定する
  depends_on = [aws_s3_bucket_policy.log_archive]
}

module "config_log_archive" {
  source = "./modules/config-recorder"
  providers = {
    aws = aws.log_archive
  }

  regions                = var.regions
  global_resource_region = var.region
  bucket_name            = aws_s3_bucket.log_archive.bucket

  depends_on = [aws_s3_bucket_policy.log_archive]
}

module "config_audit" {
  source = "./modules/config-recorder"
  providers = {
    aws = aws.audit
  }

  regions                = var.regions
  global_resource_region = var.region
  bucket_name            = aws_s3_bucket.log_archive.bucket

  depends_on = [aws_s3_bucket_policy.log_archive]
}

module "config_test" {
  source = "./modules/config-recorder"
  providers = {
    aws = aws.test
  }

  regions                = var.regions
  global_resource_region = var.region
  bucket_name            = aws_s3_bucket.log_archive.bucket

  depends_on = [aws_s3_bucket_policy.log_archive]
}

module "config_development" {
  source = "./modules/config-recorder"
  providers = {
    aws = aws.development
  }

  regions                = var.regions
  global_resource_region = var.region
  bucket_name            = aws_s3_bucket.log_archive.bucket

  depends_on = [aws_s3_bucket_policy.log_archive]
}

module "config_production" {
  source = "./modules/config-recorder"
  providers = {
    aws = aws.production
  }

  regions                = var.regions
  global_resource_region = var.region
  bucket_name            = aws_s3_bucket.log_archive.bucket

  depends_on = [aws_s3_bucket_policy.log_archive]
}

# ------------------------------------------------------------
# 集約と組織ルール：委任管理者のauditで、全アカウントの評価結果を集約し、ルールを全アカウントに展開する
# ------------------------------------------------------------

resource "aws_iam_role" "config_aggregator" {
  provider = aws.audit

  name = "config-organization-aggregator"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_aggregator" {
  provider = aws.audit

  role       = aws_iam_role.config_aggregator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

resource "aws_config_configuration_aggregator" "organization" {
  provider = aws.audit

  name = "organization"

  organization_aggregation_source {
    regions  = var.regions
    role_arn = aws_iam_role.config_aggregator.arn
  }

  depends_on = [aws_iam_role_policy_attachment.config_aggregator]
}

# 組織ルールを委任管理者（audit）から展開するとき、managementアカウントにはこのロールが自動で作られないため、別に作る
resource "aws_iam_service_linked_role" "config_multi_account_setup" {
  aws_service_name = "config-multiaccountsetup.amazonaws.com"
}

# 必須タグが付いていないリソースを検出する。検出するだけで、作成や変更は止めない
resource "aws_config_organization_managed_rule" "required_tags" {
  provider = aws.audit
  for_each = toset(var.regions)

  region          = each.key
  name            = "required-tags"
  rule_identifier = "REQUIRED_TAGS"
  # tag1Key、tag1Value（カンマ区切り）… の形式に変換する
  input_parameters = jsonencode(merge([
    for i, key in keys(var.required_tags) : merge(
      { "tag${i + 1}Key" = key },
      length(var.required_tags[key]) == 0 ? {} : { "tag${i + 1}Value" = join(",", var.required_tags[key]) },
    )
  ]...))

  depends_on = [
    aws_iam_service_linked_role.config_multi_account_setup,
    module.config_management,
    module.config_log_archive,
    module.config_audit,
    module.config_test,
    module.config_development,
    module.config_production,
  ]
}

# ------------------------------------------------------------
# 保存先バケットのポリシー：組織内の全アカウントのConfigから、配信先として確認・書き込みできるようにする
# log_archive.tf のバケットポリシーに組み込む
# ------------------------------------------------------------

data "aws_iam_policy_document" "config_bucket" {
  statement {
    sid       = "AWSConfigBucketCheck"
    actions   = ["s3:GetBucketAcl", "s3:ListBucket"]
    resources = [aws_s3_bucket.log_archive.arn]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = local.organization_account_ids
    }
  }

  statement {
    sid       = "AWSConfigBucketDelivery"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.log_archive.arn}/config/AWSLogs/*/Config/*"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = local.organization_account_ids
    }
  }
}
