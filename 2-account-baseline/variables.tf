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
    Project    = "landing-zone"
    Repository = "aws-landing-zone"
  }
}

variable "execution_role_name" {
  description = "managementから各アカウントに切り替えるときに使うIAMロール名。1-organization の scp_exempt_role_names に含めて、SCPの一部の禁止から除外しておく"
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "regions" {
  description = "Configで記録するリージョン。1-organization の allowed_regions と合わせる"
  type        = list(string)
  default     = ["ap-northeast-1", "us-east-1"]
}

variable "required_tags" {
  description = "全リソースに必須のタグ。キーはタグのキー、値は許可する値（空のリストなら値は問わない）"
  type        = map(list(string))
  default = {
    ManagedBy = ["terraform", "manual"] # terraform：default_tagsで自動で付く、manual：手作業で作ったリソース
    Project   = []
  }

  validation {
    condition     = length(var.required_tags) <= 6
    error_message = "required-tagsルールで指定できるタグは6つまで。"
  }
}

variable "log_retention_days" {
  description = "ログを保管する日数。過ぎたログはライフサイクルルールで削除する"
  type        = number
  default     = 365
}
