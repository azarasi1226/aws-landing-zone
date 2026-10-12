# 組織のアカウントIDを、アカウント名で引けるようにする。managementの認証情報で実行する
data "aws_organizations_organization" "this" {}

locals {
  ids = merge(
    { for account in data.aws_organizations_organization.this.accounts : account.name => account.id },
    { management = data.aws_organizations_organization.this.master_account_id },
  )
}
