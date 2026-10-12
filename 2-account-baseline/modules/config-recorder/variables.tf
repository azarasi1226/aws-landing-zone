variable "regions" {
  description = "Configで記録するリージョン"
  type        = list(string)
}

variable "global_resource_region" {
  description = "IAMなどのグローバルリソースを記録するリージョン。重複して記録・課金されないよう、1つのリージョンだけで記録する"
  type        = string
}

variable "bucket_name" {
  description = "記録した設定の履歴・スナップショットを送るS3バケット（log-archiveアカウント）"
  type        = string
}

variable "s3_key_prefix" {
  description = "S3バケットに保存するときのプレフィックス"
  type        = string
  default     = "config"
}
