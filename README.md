# AWS Landing Zone

AWS Organizationsの構成（OU、アカウント、SCP）と、IAM Identity Centerによる各アカウントへのアクセス、各アカウント内の共通リソース（ログ基盤、セキュリティ監視、アカウントベースラインなど）を管理するリポジトリです。

[📚 ドキュメントサイト](https://azarasi1226.github.io/aws-landing-zone/)

- `1-organization/`：組織の構成とアクセス管理
- `2-foundation/`：各アカウント内の共通リソース

## 目的

- AWS Organizationsを用いたマルチアカウント構成を作成する
- OUごとの責務分離とアカウント管理を行う
- SCPによる共通ガードレールを適用する
- IAM Identity Centerで、誰がどのアカウントにどの権限でアクセスできるかを管理する

## 前提条件

以下は手動で用意済みであることを前提とし、このリポジトリでは作成しません。

- management account：AWS Organizationsを有効化したアカウント
- Root OU：AWS Organizationsの有効化時に自動作成される
- IAM Identity Center：management accountで組織インスタンスとして有効化し、Terraform実行者に管理者権限の許可セットを割り当て済み
- Terraformのstateを保存するS3バケット

> Terraform実行者への管理者権限の割り当ては、設定ミスで自分が締め出されないよう、Terraformでは管理せず手動のまま残します。

組織そのもの（`aws_organizations_organization`）はimportして管理し、management accountのIDとRoot OUのIDはそこから取得します。

## AWS Organizationsの構成

OUの階層と各アカウントの役割は、[AWS Organizationsのドキュメント](https://azarasi1226.github.io/aws-landing-zone/organizations.html)にまとめています。

## 管理対象

| サービス | 対象アカウント | 概要 |
|---|---|---|
| [AWS Organizations](https://azarasi1226.github.io/aws-landing-zone/organizations.html) | management | OU・アカウントの作成と管理、委任管理者の登録 |
| [SCP](https://azarasi1226.github.io/aws-landing-zone/scp.html) | 全アカウント | 全アカウント共通のガードレール |
| [IAM Identity Center](https://azarasi1226.github.io/aws-landing-zone/iam-identity-center.html) | 全アカウント | グループ、許可セットと、各アカウントへの割り当て（ユーザーは手動管理） |
| [AWS Config](https://azarasi1226.github.io/aws-landing-zone/config.html) | 全アカウント | 設定の記録（log-archiveに保管）、評価結果の集約と組織ルール（audit） |
| [タグの方針](https://azarasi1226.github.io/aws-landing-zone/tagging.html) | 全アカウント | 必須タグを`default_tags`で付け、Configの`required-tags`ルールで漏れを検知 |

## Terraform構成

```text
.
├── README.md
├── docs/
├── 1-organization/          # entrypoint：managementで実行
│   ├── main.tf              # 委任管理者の設定、配下OUの呼び出し
│   ├── scp.tf               # Root OUに適用するSCP
│   ├── identity_center.tf                  # Identity Centerの共通設定
│   ├── identity_center_groups.tf           # グループと、アカウントへの割り当て
│   ├── identity_center_permission_sets.tf  # 許可セット
│   ├── providers.tf
│   ├── backend.tf
│   ├── backend.hcl.example
│   ├── versions.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   ├── outputs.tf           # アカウントID
│   ├── security-ou/
│   │   ├── main.tf          # OUとlog-archive、auditアカウントの作成
│   │   └── scp.tf           # security-ouに適用するSCP
│   ├── workload-ou/
│   │   └── main.tf          # OUとtest、development、productionアカウントの作成
│   └── modules/
│       └── scp/             # SCPの定義と適用
└── 2-foundation/            # entrypoint：managementで実行し、各アカウントのロールに切り替える
    ├── providers.tf         # アカウントごとのprovider
    ├── log_archive.tf       # ログ保管用S3バケット（log-archive）
    ├── config.tf            # Configのレコーダー（全アカウント）、アグリゲーター・組織ルール（audit）
    └── modules/
        ├── accounts/        # アカウント名からアカウントIDを引く
        └── config-recorder/ # 1アカウント分のConfigのレコーダー
```

`1-organization/`と`2-foundation/`は、それぞれ別のstateを持ちます。初回は`1-organization/`、`2-foundation/`の順にapplyします。

分けている理由と、各アカウントへの入り方は[Terraformの構成のドキュメント](https://azarasi1226.github.io/aws-landing-zone/terraform.html)にまとめています。

### 使い方

VS Codeで「Dev Containers: Reopen in Container」を実行し、dev containerの中で作業します。Terraformのバージョンは`.devcontainer/devcontainer.json`で固定しています。

```bash
cd organization
cp backend.hcl.example backend.hcl            # stateのS3バケットを設定
cp terraform.tfvars.example terraform.tfvars  # アカウントのメールアドレスを設定

export AWS_PROFILE=<managementの管理者プロファイル>
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

`2-foundation/`も、同じ手順で実行します（`terraform.tfvars`は不要）。

### アカウント追加時の手順

1. `1-organization/`でアカウントを追加してapplyする
2. `2-foundation/`の`providers.tf`と`config.tf`に、追加したアカウントのproviderとConfigのレコーダーを追加してapplyする

### 既存リソースのTerraform移行

既存の組織、OU、アカウントは、初回のplan前に`terraform import`で状態へ取り込みます。

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

import後の`terraform plan`で、以下に差分がないことを確認してからapplyします。

- `aws_service_access_principals`：既に有効なサービスが変数に含まれていないと、そのサービスの信頼されたアクセスが無効化される
- アカウントの`name`、`email`：既存の値と異なると、アカウントの作り直しになる場合がある

## 設計上の注意点

- SCPは管理アカウントには適用されない。管理アカウントはSCPに頼らず、アクセスできるユーザーとロールを最小限に絞る