resource "aws_organizations_policy" "this" {
  name        = var.name
  description = var.description
  type        = "SERVICE_CONTROL_POLICY"

  # SCPは5,120文字の上限があるため、空白を除いて登録する
  content = jsonencode(jsondecode(var.content))
}

resource "aws_organizations_policy_attachment" "this" {
  for_each = var.targets

  policy_id = aws_organizations_policy.this.id
  target_id = each.value
}
