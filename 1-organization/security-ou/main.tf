resource "aws_organizations_organizational_unit" "this" {
  name      = "security"
  parent_id = var.parent_id
}

resource "aws_organizations_account" "log_archive" {
  name      = "log-archive"
  email     = var.emails.log_archive
  parent_id = aws_organizations_organizational_unit.this.id

  # Terraform上で削除してもアカウントは閉鎖せず、組織から外すだけにする（単独のアカウントとして残る）
  close_on_deletion = false

  lifecycle {
    # 削除や作り直しになる変更をplanの段階でエラーにして止める
    prevent_destroy = true
    # 作成時にのみ使われ、importしたアカウントでは差分になるため無視する
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}

resource "aws_organizations_account" "audit" {
  name      = "audit"
  email     = var.emails.audit
  parent_id = aws_organizations_organizational_unit.this.id

  # Terraform上で削除してもアカウントは閉鎖せず、組織から外すだけにする（単独のアカウントとして残る）
  close_on_deletion = false

  lifecycle {
    # 削除や作り直しになる変更をplanの段階でエラーにして止める
    prevent_destroy = true
    # 作成時にのみ使われ、importしたアカウントでは差分になるため無視する
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}
