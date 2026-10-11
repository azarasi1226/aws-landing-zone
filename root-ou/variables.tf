variable "region" {
  description = "providerのリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "default_tags" {
  description = "全リソースに付与するタグ"
  type        = map(string)
  default = {
    ManagedBy  = "terraform"
    Repository = "aws-organization"
  }
}

# ------------------------------------------------------------
# Organizations
# ------------------------------------------------------------

variable "aws_service_access_principals" {
  description = "信頼されたアクセスを有効にするAWSサービス。既に有効なサービスを外すと無効化されるため、import後のplanで差分を確認する"
  type        = list(string)
  default = [
    "cloudtrail.amazonaws.com",                   # 全アカウントの操作ログを1つの証跡で記録する
    "config.amazonaws.com",                       # 全アカウントの設定の評価結果を集約する
    "config-multiaccountsetup.amazonaws.com",     # Configのルールを全アカウントに展開する
    "guardduty.amazonaws.com",                    # 全アカウントの脅威検知をauditで管理する
    "malware-protection.guardduty.amazonaws.com", # GuardDutyのマルウェア保護
    "securityhub.amazonaws.com",                  # 全アカウントの検出結果をauditに集約する
    "sso.amazonaws.com",                          # IAM Identity Centerで全アカウントにアクセスする
    "tagpolicies.tag.amazonaws.com",              # タグポリシー
  ]
}

variable "account_emails" {
  description = "management以外の各アカウントのルートユーザーのメールアドレス"
  type = object({
    log_archive = string
    audit       = string
    test        = string
    development = string
    production  = string
  })
}

variable "security_regions" {
  description = "auditアカウントをGuardDuty、Security Hubの委任管理者にするリージョン"
  type        = list(string)
  default     = ["ap-northeast-1"]
}

# ------------------------------------------------------------
# SCP
# ------------------------------------------------------------

variable "allowed_regions" {
  description = "利用を許可するリージョン"
  type        = list(string)
  default     = ["ap-northeast-1", "us-east-1"]
}

variable "scp_exempt_role_names" {
  description = "セキュリティサービスの設定変更とリージョン制限から除外するIAMロール名（aws-foundationの実行ロールなど）"
  type        = list(string)
  default     = ["OrganizationAccountAccessRole"]
}

# ------------------------------------------------------------
# タグ
# ------------------------------------------------------------

variable "tag_rules" {
  description = <<-EOT
    タグのルール。キーはタグのキー名（大文字・小文字を含めて統一する表記）
    - values：許可する値。省略時は値を制限しない
    - enforced_for：values に合わないタグ付けを拒否するリソースの種類（例：ec2:ALL_SUPPORTED）
  EOT
  type = map(object({
    values       = optional(list(string))
    enforced_for = optional(list(string), [])
  }))
  default = {}
}
