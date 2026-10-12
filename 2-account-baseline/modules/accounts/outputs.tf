output "organization_id" {
  description = "組織のID"
  value       = data.aws_organizations_organization.this.id
}

output "ids" {
  description = "アカウント名（log-archive、auditなど）をキーにしたアカウントID。managementアカウントは management で引ける"
  value       = local.ids
}
