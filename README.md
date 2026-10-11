# AWS Organizations Terraform

AWS Organizationsの構成（OU、アカウント、SCP、タグポリシー）と、IAM Identity Centerによる各アカウントへのアクセスを管理するリポジトリです。

各アカウント内のリソース（ログ基盤、セキュリティ監視、アカウントベースラインなど）は`aws-foundation`リポジトリで管理します。

## 目的

- AWS Organizationsを用いたマルチアカウント構成を作成する
- OUごとの責務分離とアカウント管理を行う
- SCPによる共通ガードレールを適用する
- タグポリシーでタグの表記を統一する
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

```text
📁 Root OU
├── 👤 management account
│
├── 📁 security OU
│   ├── 👤 log-archive account
│   └── 👤 audit account
│
└── 📁 workload OU
    ├── 👤 test account
    ├── 👤 development account
    └── 👤 production account
```

## OUとアカウントの役割

### 👤 management account

AWS Organizationsの管理アカウントです。以下の管理を行います。

- Organizationsの構成管理
- AWSアカウントの作成・招待・削除
- 請求・予算・コスト管理
- ルートアカウントの運用

> 管理アカウントには、アプリケーションや本番ワークロードを直接配置しないことを推奨します。

### 📁 security OU

セキュリティ監視・監査を担当するOUです。

- 👤 log-archive account：ログを集約・長期保管する
  - CloudTrail
  - Config
- 👤 audit account：委任管理者として組織全体を監視し、セキュリティ通知・運用の受け皿となる
  - GuardDuty
  - Security Hub

### 📁 workload OU

アプリケーションワークロードを配置するOUです。

- 👤 test account
- 👤 development account
- 👤 production account

## 管理対象

| サービス | 対象アカウント | 概要 |
|---|---|---|
| [AWS Organizations](docs/organizations.html) | management | OU・アカウントの作成と管理、委任管理者の登録 |
| [SCP](docs/scp.html) | 全アカウント | 全アカウント共通のガードレール |
| [タグポリシー](docs/tag-policy.html) | 全アカウント | タグのキー名・値の表記統一 |
| [IAM Identity Center](docs/iam-identity-center.html) | 全アカウント | グループ、許可セットと、各アカウントへの割り当て（ユーザーは手動管理） |

## Terraform構成

```text
.
├── README.md
├── docs/
├── root-ou/                 # entrypoint：managementで実行
│   ├── main.tf              # 委任管理者の設定、配下OUの呼び出し
│   ├── scp.tf               # Root OUに適用するSCP
│   ├── tag_policy.tf
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
│   └── workload-ou/
│       └── main.tf          # OUとtest、development、productionアカウントの作成
└── modules/
    └── scp/                 # SCPの定義と適用
```

### 使い方

```bash
cd root-ou
cp backend.hcl.example backend.hcl            # stateのS3バケットを設定
cp terraform.tfvars.example terraform.tfvars  # アカウントのメールアドレスなどを設定

export AWS_PROFILE=<managementの管理者プロファイル>
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

### アカウント追加時の手順

1. このリポジトリでアカウントを追加してapplyする
2. `outputs.tf`で出力されたアカウントIDを、`aws-foundation`リポジトリの変数に追加する
3. `aws-foundation`リポジトリでアカウント内のリソースを作成する

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

- `aws_service_access_principals`：既に有効なサービスが変数に含まれていないと、そのサービスの組織連携が無効化される
- アカウントの`name`、`email`：既存の値と異なると、アカウントの作り直しになる場合がある

## 設計上の注意点

- SCPは管理アカウントには適用されない。管理アカウントはSCPに頼らず、アクセスできるユーザーとロールを最小限に絞る