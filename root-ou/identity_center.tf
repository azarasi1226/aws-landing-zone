# IAM Identity Centerの共通設定。グループは identity_center_groups.tf、許可セットは identity_center_permission_sets.tf

data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}
