output "ou_id" {
  description = "workload OUのID"
  value       = aws_organizations_organizational_unit.this.id
}

output "account_ids" {
  description = "workload OU配下のアカウントID"
  value = {
    test        = aws_organizations_account.test.id
    development = aws_organizations_account.development.id
    production  = aws_organizations_account.production.id
  }
}
