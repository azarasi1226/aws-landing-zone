# 許可セット。各グループへの割り当ては identity_center_groups.tf の local.sso_groups で行う

locals {
  # description は英数字と一部の記号しか使えない（日本語不可）
  sso_permission_sets = {
    Admin = {
      description         = "Full administrator access"
      session_duration    = "PT1H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
      inline_policy       = null
    }
    PowerUser = {
      description         = "All operations except IAM, Organizations, and account settings"
      session_duration    = "PT4H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/PowerUserAccess"]
      inline_policy       = null
    }
    Observer = {
      description         = "Read-only access to resources, plus logs and metrics for troubleshooting"
      session_duration    = "PT4H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"]
      # ViewOnlyAccessではログの中身とメトリクスの値が読めないため追加する
      inline_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "ReadLogs"
            Effect = "Allow"
            Action = [
              "logs:GetLogEvents",
              "logs:FilterLogEvents",
              "logs:GetLogRecord",
              "logs:StartQuery",
              "logs:StopQuery",
              "logs:GetQueryResults",
              "logs:StartLiveTail",
              "logs:StopLiveTail",
            ]
            Resource = "*"
          },
          {
            Sid    = "ReadMetrics"
            Effect = "Allow"
            Action = [
              "cloudwatch:GetMetricData",
              "cloudwatch:GetMetricStatistics",
              "cloudwatch:GetMetricWidgetImage",
              "cloudwatch:GetDashboard",
            ]
            Resource = "*"
          },
        ]
      })
    }
    SecurityAudit = {
      description      = "Read-only security review, plus CloudTrail log investigation in audit"
      session_duration = "PT4H"
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/SecurityAudit",
        "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess",
      ]
      # auditのAthenaでCloudTrailのログを調査できるようにする
      # 対象のリソースは 2-account-baseline/cloudtrail.tf で作るものだけに絞る（名前を合わせる）
      inline_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "RunCloudTrailQueries"
            Effect = "Allow"
            Action = [
              "athena:StartQueryExecution",
              "athena:StopQueryExecution",
              "athena:GetQueryExecution",
              "athena:GetQueryResults",
              "athena:GetQueryResultsStream",
              "athena:ListQueryExecutions",
              "athena:GetWorkGroup",
            ]
            Resource = "arn:aws:athena:${var.region}:${local.cloudtrail_investigation.audit_account_id}:workgroup/cloudtrail"
          },
          {
            Sid    = "ReadCloudTrailTable"
            Effect = "Allow"
            Action = [
              "athena:GetDataCatalog",
              "athena:ListDatabases",
              "athena:GetDatabase",
              "athena:ListTableMetadata",
              "athena:GetTableMetadata",
              "glue:GetDatabase",
              "glue:GetDatabases",
              "glue:GetTable",
              "glue:GetTables",
              "glue:GetPartition",
              "glue:GetPartitions",
            ]
            Resource = [
              "arn:aws:athena:${var.region}:${local.cloudtrail_investigation.audit_account_id}:datacatalog/AwsDataCatalog",
              "arn:aws:glue:${var.region}:${local.cloudtrail_investigation.audit_account_id}:catalog",
              "arn:aws:glue:${var.region}:${local.cloudtrail_investigation.audit_account_id}:database/cloudtrail",
              "arn:aws:glue:${var.region}:${local.cloudtrail_investigation.audit_account_id}:table/cloudtrail/*",
            ]
          },
          {
            Sid      = "ReadCloudTrailLogs"
            Effect   = "Allow"
            Action   = ["s3:GetObject"]
            Resource = "arn:aws:s3:::${local.cloudtrail_investigation.log_bucket}/cloudtrail/*"
          },
          {
            Sid      = "ListCloudTrailLogs"
            Effect   = "Allow"
            Action   = ["s3:ListBucket"]
            Resource = "arn:aws:s3:::${local.cloudtrail_investigation.log_bucket}"
            Condition = {
              StringLike = { "s3:prefix" = ["cloudtrail/*"] }
            }
          },
          {
            Sid      = "LocateCloudTrailLogs"
            Effect   = "Allow"
            Action   = ["s3:GetBucketLocation"]
            Resource = "arn:aws:s3:::${local.cloudtrail_investigation.log_bucket}"
          },
          {
            Sid    = "WriteQueryResults"
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:AbortMultipartUpload",
              "s3:ListMultipartUploadParts",
            ]
            Resource = "arn:aws:s3:::${local.cloudtrail_investigation.results_bucket}/*"
          },
          {
            Sid      = "ListQueryResults"
            Effect   = "Allow"
            Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
            Resource = "arn:aws:s3:::${local.cloudtrail_investigation.results_bucket}"
          },
        ]
      })
    }
  }

  # 2-account-baseline/cloudtrail.tf で作る、CloudTrailのログの調査に使うリソースの名前
  cloudtrail_investigation = {
    audit_account_id = local.account_ids["audit"]
    log_bucket       = "log-archive-${local.account_ids["log-archive"]}"
    results_bucket   = "athena-results-${local.account_ids["audit"]}"
  }

  sso_managed_policy_attachments = {
    for a in flatten([
      for ps, p in local.sso_permission_sets : [
        for arn in p.managed_policy_arns : { permission_set = ps, arn = arn }
      ]
    ]) : "${a.permission_set}/${a.arn}" => a
  }
}

resource "aws_ssoadmin_permission_set" "this" {
  for_each = local.sso_permission_sets

  instance_arn     = local.sso_instance_arn
  name             = each.key
  description      = each.value.description
  session_duration = each.value.session_duration
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = local.sso_managed_policy_attachments

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn
  managed_policy_arn = each.value.arn
}

resource "aws_ssoadmin_permission_set_inline_policy" "this" {
  for_each = { for ps, p in local.sso_permission_sets : ps => p if p.inline_policy != null }

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
  inline_policy      = each.value.inline_policy
}
