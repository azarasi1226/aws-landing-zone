variable "name" {
  description = "SCPの名前"
  type        = string
}

variable "description" {
  description = "SCPの説明"
  type        = string
  default     = null
}

variable "content" {
  description = "SCPのポリシードキュメント（JSON）"
  type        = string
}

variable "targets" {
  description = <<-EOT
    SCPを適用する対象。キーは任意の識別名、値は以下のいずれかのID
    - Root：r-xxxx（例：r-ab12）
    - OU：ou-xxxx-xxxxxxxx（例：ou-ab12-cd34ef56）
    - アカウント：12桁の数字（例：111111111111）
  EOT
  type        = map(string)

  validation {
    condition = alltrue([
      for id in values(var.targets) : can(regex("^(r-[0-9a-z]{4,32}|ou-[0-9a-z]{4,32}-[a-z0-9]{8,32}|[0-9]{12})$", id))
    ])
    error_message = "targets の値は Root（r-xxxx）、OU（ou-xxxx-xxxxxxxx）、アカウント（12桁の数字）のいずれかのIDを指定してください。"
  }
}
