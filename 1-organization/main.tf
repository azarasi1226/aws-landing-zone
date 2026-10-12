# 既存の組織をimportして管理する
resource "aws_organizations_organization" "this" {
  # すべての機能。一括請求のみ（CONSOLIDATED_BILLING）では、SCP、信頼されたアクセスが使えない
  feature_set                   = "ALL"
  aws_service_access_principals = var.aws_service_access_principals

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
  ]

  lifecycle {
    # 削除や作り直しになる変更をplanの段階でエラーにして止める
    prevent_destroy = true
  }
}

locals {
  root_id               = aws_organizations_organization.this.roots[0].id
  management_account_id = aws_organizations_organization.this.master_account_id

  account_ids = merge(
    { management = local.management_account_id },
    module.security_ou.account_ids,
    module.workload_ou.account_ids,
  )
}

module "security_ou" {
  source = "./security-ou"

  parent_id = local.root_id
  emails = {
    log_archive = var.account_emails.log_archive
    audit       = var.account_emails.audit
  }
  scp_exempt_role_arns = local.scp_exempt_role_arns
}

module "workload_ou" {
  source = "./workload-ou"

  parent_id = local.root_id
  emails = {
    test        = var.account_emails.test
    development = var.account_emails.development
    production  = var.account_emails.production
  }
}

# ------------------------------------------------------------
# 委任管理者
# 本来managementでしか行えない「組織全体を対象にしたサービスの管理」をauditに任せる。
# 各サービスの組織全体での有効化や設定は、2-account-baseline/ からauditで行う
# ------------------------------------------------------------

# GuardDuty：全アカウントの脅威検知の有効化と、検出結果の集約をauditで行う。リージョンごとに登録が必要
resource "aws_guardduty_organization_admin_account" "audit" {
  for_each = toset(var.security_regions)

  region           = each.key
  admin_account_id = module.security_ou.account_ids["audit"]

  depends_on = [aws_organizations_organization.this]
}

# Security Hub：全アカウントの検出結果の集約とセキュリティ評価をauditで行う。リージョンごとに登録が必要
resource "aws_securityhub_organization_admin_account" "audit" {
  for_each = toset(var.security_regions)

  region           = each.key
  admin_account_id = module.security_ou.account_ids["audit"]

  depends_on = [aws_organizations_organization.this]
}

# AWS Config：組織単位の機能をauditで使えるようにする。組織全体で1回の登録でよい
resource "aws_organizations_delegated_administrator" "audit" {
  for_each = toset([
    "config.amazonaws.com",                   # アグリゲーター（全アカウントの評価結果の集約）
    "config-multiaccountsetup.amazonaws.com", # 組織ルール、コンフォーマンスパックの全アカウントへの展開
  ])

  account_id        = module.security_ou.account_ids["audit"]
  service_principal = each.key

  depends_on = [aws_organizations_organization.this]
}
