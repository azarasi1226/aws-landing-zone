# Root OUに適用するSCP（managementアカウントには適用されない）

locals {
  # セキュリティサービスの設定やリージョン制限から除外するロール
  scp_exempt_role_arns = [for name in var.scp_exempt_role_names : "arn:aws:iam::*:role/${name}"]
}

data "aws_iam_policy_document" "guardrails" {
  statement {
    sid       = "DenyLeaveOrganization"
    effect    = "Deny"
    actions   = ["organizations:LeaveOrganization"]
    resources = ["*"]
  }

  statement {
    sid       = "DenyRootUser"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::*:root"]
    }
  }

  statement {
    sid    = "DenyIamUserAndAccessKey"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateAccessKey",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyDisableSecurityServices"
    effect = "Deny"
    actions = [
      "cloudtrail:DeleteTrail",
      "cloudtrail:StopLogging",
      "cloudtrail:UpdateTrail",
      "cloudtrail:PutEventSelectors",
      "config:DeleteConfigurationRecorder",
      "config:DeleteDeliveryChannel",
      "config:DeleteRetentionConfiguration",
      "config:StopConfigurationRecorder",
      "guardduty:DeleteDetector",
      "guardduty:DisassociateFromAdministratorAccount",
      "guardduty:DisassociateFromMasterAccount",
      "guardduty:UpdateDetector",
      "securityhub:DisableSecurityHub",
      "securityhub:DisassociateFromAdministratorAccount",
      "securityhub:DisassociateFromMasterAccount",
    ]
    resources = ["*"]

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = local.scp_exempt_role_arns
    }
  }
}

# グローバルサービスを除き、許可リージョン以外の操作を禁止する
# not_actions には、リージョンを持たないグローバルサービスと、認証に使うSTSだけを並べる（KMSやConfigなどリージョンごとのサービスは入れない）
data "aws_iam_policy_document" "region_restriction" {
  statement {
    sid    = "DenyOutsideAllowedRegions"
    effect = "Deny"
    not_actions = [
      "a4b:*",
      "account:*",
      "aws-marketplace-management:*",
      "aws-marketplace:*",
      "aws-portal:*",
      "billing:*",
      "budgets:*",
      "ce:*",
      "chime:*",
      "cloudfront:*",
      "cur:*",
      "directconnect:*",
      "ec2:DescribeRegions",
      "ec2:DescribeTransitGateways",
      "ec2:DescribeVpnGateways",
      "fms:*",
      "freetier:*",
      "globalaccelerator:*",
      "health:*",
      "iam:*",
      "identitystore:*",
      "importexport:*",
      "invoicing:*",
      "networkmanager:*",
      "organizations:*",
      "payments:*",
      "pricing:*",
      "route53-recovery-cluster:*",
      "route53-recovery-control-config:*",
      "route53-recovery-readiness:*",
      "route53:*",
      "route53domains:*",
      "s3:CreateMultiRegionAccessPoint",
      "s3:DeleteMultiRegionAccessPoint",
      "s3:DescribeMultiRegionAccessPointOperation",
      "s3:GetAccountPublicAccessBlock",
      "s3:GetBucketLocation",
      "s3:GetMultiRegionAccessPoint",
      "s3:GetMultiRegionAccessPointPolicy",
      "s3:GetMultiRegionAccessPointPolicyStatus",
      "s3:GetStorageLensConfiguration",
      "s3:GetStorageLensDashboard",
      "s3:ListAllMyBuckets",
      "s3:ListMultiRegionAccessPoints",
      "s3:ListStorageLensConfigurations",
      "s3:PutAccountPublicAccessBlock",
      "s3:PutMultiRegionAccessPointPolicy",
      "savingsplans:*",
      "shield:*",
      "sso:*",
      "sts:*",
      "support:*",
      "supportapp:*",
      "supportplans:*",
      "tax:*",
      "trustedadvisor:*",
      "waf:*",
      "wafv2:*",
      "wellarchitected:*",
    ]
    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = local.scp_exempt_role_arns
    }
  }
}

module "scp_guardrails" {
  source = "./modules/scp"

  name        = "guardrails"
  description = "組織からの離脱、rootユーザーの利用、IAMユーザーの作成、セキュリティサービスの停止を禁止する"
  content     = data.aws_iam_policy_document.guardrails.json
  targets = {
    root = local.root_id
  }
}

module "scp_region_restriction" {
  source = "./modules/scp"

  name        = "region-restriction"
  description = "許可リージョン以外の利用を禁止する"
  content     = data.aws_iam_policy_document.region_restriction.json
  targets = {
    root = local.root_id
  }
}
