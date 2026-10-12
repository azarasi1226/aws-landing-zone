# 1つのアカウントで、Configのレコーダーと配信先を設定して記録を開始する

# Configが使うサービスリンクロール。アカウントに既にある場合は import する
resource "aws_iam_service_linked_role" "config" {
  aws_service_name = "config.amazonaws.com"
}

resource "aws_config_configuration_recorder" "this" {
  for_each = toset(var.regions)

  region   = each.key
  name     = "default"
  role_arn = aws_iam_service_linked_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = each.key == var.global_resource_region
  }
}

resource "aws_config_delivery_channel" "this" {
  for_each = toset(var.regions)

  region         = each.key
  name           = "default"
  s3_bucket_name = var.bucket_name
  s3_key_prefix  = var.s3_key_prefix

  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  for_each = toset(var.regions)

  region     = each.key
  name       = aws_config_configuration_recorder.this[each.key].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}
