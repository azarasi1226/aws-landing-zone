locals {
  # ログ保管用S3バケット。2-foundation/log_archive.tf では名前に「log-archive」を含めて作成する
  log_bucket_arns = ["arn:aws:s3:::*log-archive*"]
}

data "aws_iam_policy_document" "security_ou" {
  # ログの削除は、実行ロールを含めて誰にも許可しない
  statement {
    sid    = "DenyDeleteLogs"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
    ]
    resources = concat(
      local.log_bucket_arns,
      [for arn in local.log_bucket_arns : "${arn}/*"],
    )
  }

  statement {
    sid    = "DenyModifyLogBuckets"
    effect = "Deny"
    actions = [
      "s3:DeleteBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:PutBucketVersioning",
      "s3:PutBucketObjectLockConfiguration",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:PutBucketPublicAccessBlock",
    ]
    resources = local.log_bucket_arns

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = var.scp_exempt_role_arns
    }
  }

  # security OUのアカウントではアプリケーションを動かさない
  statement {
    sid    = "DenyWorkloads"
    effect = "Deny"
    actions = [
      "ec2:RunInstances",
      "ecs:CreateService",
      "ecs:RunTask",
      "eks:CreateCluster",
      "lambda:CreateFunction",
      "rds:CreateDBCluster",
      "rds:CreateDBInstance",
    ]
    resources = ["*"]

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = var.scp_exempt_role_arns
    }
  }
}

module "scp_security_ou" {
  source = "../modules/scp"

  name        = "security-ou"
  description = "ログ保管用S3バケットの削除・設定変更と、ワークロードの作成を禁止する"
  content     = data.aws_iam_policy_document.security_ou.json
  targets = {
    security-ou = aws_organizations_organizational_unit.this.id
  }
}
