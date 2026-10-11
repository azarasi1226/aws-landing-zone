# グループと、グループへの許可セット・アカウントの割り当て
# ユーザーの作成とグループへの所属は、入退社などで頻繁に変わるためIdentity Centerのコンソールで手動管理する
# Terraform実行者への管理者権限の割り当ても、締め出しを防ぐため手動で管理し、ここには含めない

locals {
  # グループと、各グループに割り当てる「許可セット => アカウント」
  sso_groups = {
    admins = {
      description = "全アカウントの管理者"
      assignments = {
        Admin = ["management", "log-archive", "audit", "test", "development", "production"]
      }
    }
    developers = {
      description = "workloadアカウントの開発者"
      assignments = {
        PowerUser = ["test", "development"]
        Observer  = ["production"]
      }
    }
    security-auditors = {
      description = "全アカウントのセキュリティ監査担当"
      assignments = {
        SecurityAudit = ["management", "log-archive", "audit", "test", "development", "production"]
      }
    }
  }

  sso_account_assignments = {
    for a in flatten([
      for group, g in local.sso_groups : [
        for permission_set, accounts in g.assignments : [
          for account in accounts : { group = group, permission_set = permission_set, account = account }
        ]
      ]
    ]) : "${a.group}/${a.permission_set}/${a.account}" => a
  }
}

resource "aws_identitystore_group" "this" {
  for_each = local.sso_groups

  identity_store_id = local.identity_store_id
  display_name      = each.key
  description       = each.value.description
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = local.sso_account_assignments

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn
  principal_type     = "GROUP"
  principal_id       = aws_identitystore_group.this[each.value.group].group_id
  target_type        = "AWS_ACCOUNT"
  target_id          = local.account_ids[each.value.account]

  # 許可セットのポリシーが揃ってから割り当てる
  depends_on = [
    aws_ssoadmin_managed_policy_attachment.this,
    aws_ssoadmin_permission_set_inline_policy.this,
  ]
}
