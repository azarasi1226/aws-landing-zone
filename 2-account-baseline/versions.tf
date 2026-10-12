terraform {
  # .devcontainer/devcontainer.json のTerraformのバージョンと合わせる
  required_version = ">= 1.16"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
