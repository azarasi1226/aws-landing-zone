variable "parent_id" {
  description = "親（Root OU）のID"
  type        = string
}

variable "emails" {
  description = "各アカウントのルートユーザーのメールアドレス"
  type = object({
    log_archive = string
    audit       = string
  })
}

variable "scp_exempt_role_arns" {
  description = "SCPの設定変更の禁止から除外するIAMロールのARN（ワイルドカード可）"
  type        = list(string)
}
