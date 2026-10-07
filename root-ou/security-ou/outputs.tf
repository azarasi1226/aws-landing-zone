output "ou_id" {
  description = "security OUのID"
  value       = aws_organizations_organizational_unit.this.id
}

output "account_ids" {
  description = "security OU配下のアカウントID"
  value = {
    log-archive = aws_organizations_account.log_archive.id
    audit       = aws_organizations_account.audit.id
  }
}
