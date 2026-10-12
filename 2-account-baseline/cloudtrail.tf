# ------------------------------------------------------------
# 組織の証跡：managementで1本作り、全アカウント・全リージョンの操作ログをlog-archiveのバケットに送る
# ------------------------------------------------------------

locals {
  cloudtrail_name = "organization"
  # 証跡を作る前にバケットポリシーで参照するため、ARNを組み立てる
  cloudtrail_arn = "arn:aws:cloudtrail:${var.region}:${module.accounts.ids["management"]}:trail/${local.cloudtrail_name}"
  # 組織の証跡のログは cloudtrail/AWSLogs/<組織ID>/<アカウントID>/CloudTrail/<リージョン>/<年>/<月>/<日>/ に保存される
  cloudtrail_logs_prefix = "cloudtrail/AWSLogs/${module.accounts.organization_id}"
}

resource "aws_cloudtrail" "organization" {
  name           = local.cloudtrail_name
  s3_bucket_name = aws_s3_bucket.log_archive.bucket
  s3_key_prefix  = "cloudtrail"

  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  # ログが改ざんされていないことを、ダイジェストファイルで検証できるようにする
  enable_log_file_validation = true

  depends_on = [aws_s3_bucket_policy.log_archive]
}

# ------------------------------------------------------------
# 保存先バケットのポリシー：log_archive.tf のバケットポリシーに組み込む
# ------------------------------------------------------------

data "aws_iam_policy_document" "cloudtrail_bucket" {
  # 組織の証跡から、配信先として確認・書き込みできるようにする
  statement {
    sid       = "AWSCloudTrailAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.log_archive.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.cloudtrail_arn]
    }
  }

  statement {
    sid     = "AWSCloudTrailWrite"
    actions = ["s3:PutObject"]
    resources = [
      # managementアカウント自身の分と、組織の全アカウントの分
      "${aws_s3_bucket.log_archive.arn}/cloudtrail/AWSLogs/${module.accounts.ids["management"]}/*",
      "${aws_s3_bucket.log_archive.arn}/${local.cloudtrail_logs_prefix}/*",
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.cloudtrail_arn]
    }
  }

  # auditアカウントから、Athenaで調査するためにログを読めるようにする
  # 実際に読めるのは、audit側のIAMでも許可された人（Admin許可セットなど）だけ
  statement {
    sid       = "AuditListCloudTrailLogs"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.log_archive.arn]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${module.accounts.ids["audit"]}:root"]
    }
  }

  statement {
    sid       = "AuditReadCloudTrailLogs"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.log_archive.arn}/cloudtrail/*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${module.accounts.ids["audit"]}:root"]
    }
  }
}

# ------------------------------------------------------------
# 調査：auditアカウントのAthenaから、SQLでログを検索できるようにする
# バケット・ワークグループ・データベースの名前を変えるときは、1-organization/identity_center_permission_sets.tf の
# SecurityAudit許可セットの権限も合わせる
# ------------------------------------------------------------

# クエリの結果を保存するバケット。結果は調査が終われば不要なため、短期間で削除する
resource "aws_s3_bucket" "athena_results" {
  provider = aws.audit

  bucket        = "athena-results-${module.accounts.ids["audit"]}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  provider = aws.audit

  bucket                  = aws_s3_bucket.athena_results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  provider = aws.audit

  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  provider = aws.audit

  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "expire-query-results"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }
  }
}

resource "aws_athena_workgroup" "cloudtrail" {
  provider = aws.audit

  name = "cloudtrail"

  configuration {
    # 利用者が結果の保存先を変えられないようにする
    enforce_workgroup_configuration = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}

resource "aws_glue_catalog_database" "cloudtrail" {
  provider = aws.audit

  name = "cloudtrail"
}

# 調査に使うリージョンの一覧。SCPで拒否された許可リージョン以外での操作も記録されるため、全リージョンを対象にする
data "aws_regions" "all" {
  provider = aws.audit

  all_regions = true
}

# 組織の証跡のログを読むテーブル。パーティション射影で、アカウント・リージョン・日付ごとに読む範囲を絞る
resource "aws_glue_catalog_table" "cloudtrail_logs" {
  provider = aws.audit

  name          = "logs"
  database_name = aws_glue_catalog_database.cloudtrail.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "projection.enabled"          = "true"
    "projection.account.type"     = "enum"
    "projection.account.values"   = join(",", local.organization_account_ids)
    "projection.region.type"      = "enum"
    "projection.region.values"    = join(",", sort(data.aws_regions.all.names))
    "projection.dt.type"          = "date"
    "projection.dt.format"        = "yyyy/MM/dd"
    "projection.dt.range"         = "2026/01/01,NOW"
    "projection.dt.interval"      = "1"
    "projection.dt.interval.unit" = "DAYS"
    "storage.location.template"   = "s3://${aws_s3_bucket.log_archive.bucket}/${local.cloudtrail_logs_prefix}/$${account}/CloudTrail/$${region}/$${dt}"
  }

  partition_keys {
    name = "account"
    type = "string"
  }

  partition_keys {
    name = "region"
    type = "string"
  }

  partition_keys {
    name = "dt"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.log_archive.bucket}/${local.cloudtrail_logs_prefix}/"
    input_format  = "com.amazon.emr.cloudtrail.CloudTrailInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hive.hcatalog.data.JsonSerDe"
    }

    columns {
      name = "eventversion"
      type = "string"
    }
    columns {
      name = "useridentity"
      type = "struct<type:string,principalid:string,arn:string,accountid:string,invokedby:string,accesskeyid:string,username:string,onbehalfof:struct<userid:string,identitystorearn:string>,sessioncontext:struct<attributes:struct<mfaauthenticated:string,creationdate:string>,sessionissuer:struct<type:string,principalid:string,arn:string,accountid:string,username:string>,sourceidentity:string,ec2roledelivery:string,webidfederationdata:map<string,string>>>"
    }
    columns {
      name = "eventtime"
      type = "string"
    }
    columns {
      name = "eventsource"
      type = "string"
    }
    columns {
      name = "eventname"
      type = "string"
    }
    columns {
      name = "awsregion"
      type = "string"
    }
    columns {
      name = "sourceipaddress"
      type = "string"
    }
    columns {
      name = "useragent"
      type = "string"
    }
    columns {
      name = "errorcode"
      type = "string"
    }
    columns {
      name = "errormessage"
      type = "string"
    }
    columns {
      name = "requestparameters"
      type = "string"
    }
    columns {
      name = "responseelements"
      type = "string"
    }
    columns {
      name = "additionaleventdata"
      type = "string"
    }
    columns {
      name = "requestid"
      type = "string"
    }
    columns {
      name = "eventid"
      type = "string"
    }
    columns {
      name = "readonly"
      type = "string"
    }
    columns {
      name = "resources"
      type = "array<struct<arn:string,accountid:string,type:string>>"
    }
    columns {
      name = "eventtype"
      type = "string"
    }
    columns {
      name = "apiversion"
      type = "string"
    }
    columns {
      name = "recipientaccountid"
      type = "string"
    }
    columns {
      name = "serviceeventdetails"
      type = "string"
    }
    columns {
      name = "sharedeventid"
      type = "string"
    }
    columns {
      name = "vpcendpointid"
      type = "string"
    }
    columns {
      name = "tlsdetails"
      type = "struct<tlsversion:string,ciphersuite:string,clientprovidedhostheader:string>"
    }
  }
}
