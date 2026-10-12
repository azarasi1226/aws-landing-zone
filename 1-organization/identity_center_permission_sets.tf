# 許可セット。各グループへの割り当ては identity_center_groups.tf の local.sso_groups で行う

locals {
  sso_permission_sets = {
    Admin = {
      description         = "管理者権限"
      session_duration    = "PT1H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
      inline_policy       = null
    }
    PowerUser = {
      description         = "IAM・Organizations・アカウント設定以外のすべての操作"
      session_duration    = "PT4H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/PowerUserAccess"]
      inline_policy       = null
    }
    Observer = {
      description         = "リソースの閲覧と、障害調査のためのログ・メトリクスの読み取り。変更はできない"
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
      description      = "セキュリティ設定と、リソースの一覧・設定の閲覧のみ。データは読めない"
      session_duration = "PT4H"
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/SecurityAudit",
        "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess",
      ]
      inline_policy = null
    }
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
