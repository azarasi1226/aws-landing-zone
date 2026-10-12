output "organization_id" {
  description = "組織のID"
  value       = aws_organizations_organization.this.id
}

output "root_id" {
  description = "Root OUのID"
  value       = local.root_id
}

output "ou_ids" {
  description = "OUのID"
  value = {
    security-ou = module.security_ou.ou_id
    workload-ou = module.workload_ou.ou_id
  }
}

output "account_ids" {
  description = "アカウントID"
  value       = local.account_ids
}
