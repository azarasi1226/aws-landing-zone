# タグのキー名・値の表記を統一する。var.tag_rules が空の場合は作成しない

resource "aws_organizations_policy" "tag_policy" {
  count = length(var.tag_rules) > 0 ? 1 : 0

  name        = "tag-policy"
  description = "タグのキー名・値の表記を統一する"
  type        = "TAG_POLICY"

  content = jsonencode({
    tags = {
      for key, tag in var.tag_rules : lower(key) => merge(
        { tag_key = { "@@assign" = key } },
        tag.values == null ? {} : { tag_value = { "@@assign" = tag.values } },
        length(tag.enforced_for) == 0 ? {} : { enforced_for = { "@@assign" = tag.enforced_for } },
      )
    }
  })
}

resource "aws_organizations_policy_attachment" "tag_policy" {
  count = length(var.tag_rules) > 0 ? 1 : 0

  policy_id = aws_organizations_policy.tag_policy[0].id
  target_id = local.root_id
}
