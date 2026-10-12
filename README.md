# AWS Landing Zone

AWS Organizationsの構成（OU、アカウント、SCP）と、IAM Identity Centerによる各アカウントへのアクセス、各アカウント内の共通リソース（ログ基盤、セキュリティ監視、ガバナンスなど）を管理するリポジトリです。

[📚 ドキュメントサイト](https://azarasi1226.github.io/aws-landing-zone/)

- `1-organization/`：組織の構成とアクセス管理
- `2-account-baseline/`：各アカウント内の共通リソース

## 前提条件

以下は手動で用意済みであることを前提とし、このリポジトリでは作成しません。

- management account：AWS Organizationsを有効化したアカウント
- Root OU：AWS Organizationsの有効化時に自動作成される
- IAM Identity Center：management accountで組織インスタンスとして有効化し、Terraform実行者に管理者権限の許可セットを割り当て済み
- Terraformのstateを保存するS3バケット
- 各アカウントの`OrganizationAccountAccessRole`：Organizationsで作成したアカウントには自動で作られる。招待で参加したアカウントには、`2-account-baseline/`の実行前に作成する

> Terraform実行者への管理者権限の割り当ては、設定ミスで自分が締め出されないよう、Terraformでは管理せず手動のまま残します。

## 使い方

VS Codeで「Dev Containers: Reopen in Container」を実行し、dev containerの中で作業します。Terraformのバージョンは`.devcontainer/devcontainer.json`で固定しています。

```bash
cd 1-organization
cp backend.hcl.example backend.hcl            # stateのS3バケットを設定
cp terraform.tfvars.example terraform.tfvars  # アカウントのメールアドレスを設定

export AWS_PROFILE=<managementの管理者プロファイル>
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

`2-account-baseline/`も、同じ手順で実行します（`terraform.tfvars`は不要）。初回は`1-organization/`、`2-account-baseline/`の順にapplyします。分けている理由、各アカウントへの入り方、アカウント追加の手順は[Terraformの構成のドキュメント](https://azarasi1226.github.io/aws-landing-zone/terraform.html)にまとめています。

## 既存リソースのTerraform移行

既存の組織、OU、アカウントは、初回のplan前に`terraform import`でstateへ取り込みます。

```bash
terraform import aws_organizations_organization.this o-xxxxxxxxxx
terraform import module.security_ou.aws_organizations_organizational_unit.this ou-xxxx-xxxxxxxx
terraform import module.security_ou.aws_organizations_account.log_archive 111111111111
terraform import module.security_ou.aws_organizations_account.audit 222222222222
terraform import module.workload_ou.aws_organizations_organizational_unit.this ou-xxxx-yyyyyyyy
terraform import module.workload_ou.aws_organizations_account.test 333333333333
terraform import module.workload_ou.aws_organizations_account.development 444444444444
terraform import module.workload_ou.aws_organizations_account.production 555555555555
```

import後の`terraform plan`で確認すべきことは、[AWS Organizationsのドキュメント](https://azarasi1226.github.io/aws-landing-zone/organizations.html)にまとめています。
