# managementアカウントの認証情報で実行する（AWS_PROFILEなど）
provider "aws" {
  region = var.region

  default_tags {
    tags = var.default_tags
  }
}
