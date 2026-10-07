variable "parent_id" {
  description = "親（Root OU）のID"
  type        = string
}

variable "emails" {
  description = "各アカウントのルートユーザーのメールアドレス"
  type = object({
    test        = string
    development = string
    production  = string
  })
}
