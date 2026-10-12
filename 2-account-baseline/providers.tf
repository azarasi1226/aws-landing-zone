# managementアカウントの認証情報で実行する（AWS_PROFILEなど）。アカウントIDの参照に使う
provider "aws" {
  region = var.region

  default_tags {
    tags = var.default_tags
  }
}

# log-archiveアカウント。managementから execution_role_name のロールに切り替えて操作する
provider "aws" {
  alias  = "log_archive"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${module.accounts.ids["log-archive"]}:role/${var.execution_role_name}"
  }

  default_tags {
    tags = var.default_tags
  }
}

# auditアカウント。managementから execution_role_name のロールに切り替えて操作する
provider "aws" {
  alias  = "audit"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${module.accounts.ids["audit"]}:role/${var.execution_role_name}"
  }

  default_tags {
    tags = var.default_tags
  }
}

# testアカウント。managementから execution_role_name のロールに切り替えて操作する
provider "aws" {
  alias  = "test"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${module.accounts.ids["test"]}:role/${var.execution_role_name}"
  }

  default_tags {
    tags = var.default_tags
  }
}

# developmentアカウント。managementから execution_role_name のロールに切り替えて操作する
provider "aws" {
  alias  = "development"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${module.accounts.ids["development"]}:role/${var.execution_role_name}"
  }

  default_tags {
    tags = var.default_tags
  }
}

# productionアカウント。managementから execution_role_name のロールに切り替えて操作する
provider "aws" {
  alias  = "production"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${module.accounts.ids["production"]}:role/${var.execution_role_name}"
  }

  default_tags {
    tags = var.default_tags
  }
}
