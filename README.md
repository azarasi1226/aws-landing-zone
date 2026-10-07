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

> Terraform実行者への管理者権限の割り当ては、設定ミスで自分が締め出されないよう、Terraformでは管理せず手動のまま残します。

management accountのIDとRoot OUのIDは変数で渡します（[既存のRoot OUと管理アカウントID](#既存のroot-ouと管理アカウントid)）。

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
| [AWS Organizations](docs/organizations.md) | management | OU・アカウントの作成と管理、委任管理者の登録 |
| [SCP](docs/scp.md) | 全アカウント | 全アカウント共通のガードレール |
| [タグポリシー](docs/tag-policy.md) | 全アカウント | タグのキー名・値の表記統一 |
| [IAM Identity Center](docs/iam-identity-center.md) | 全アカウント | ユーザー、グループ、許可セットと、各アカウントへの割り当て |

## Terraform構成

```text
.
├── README.md
├── docs/
├── root-ou/                 # entrypoint：managementで実行
│   ├── main.tf              # 委任管理者の設定、配下OUの呼び出し
│   ├── scp.tf               # Root OUに適用するSCP
│   ├── tag_policy.tf
│   ├── identity_center.tf   # ユーザー、グループ、許可セット、アカウントへの割り当て
│   ├── providers.tf
│   ├── backend.tf
│   ├── versions.tf
│   ├── variables.tf
│   ├── outputs.tf           # アカウントID
│   ├── security-ou/
│   │   ├── main.tf          # OUとlog-archive、auditアカウントの作成
│   │   └── scp.tf           # security-ouに適用するSCP
│   └── workload-ou/
│       ├── main.tf          # OUとtest、development、productionアカウントの作成
│       └── scp.tf           # workload-ouに適用するSCP
└── modules/
    └── scp/                 # SCPの定義と適用
```

`root-ou/`はAWS Organizationsの構成をフォルダ階層で表します。各OUのSCPはそのOUのフォルダに置きます。

### アカウント追加時の手順

1. このリポジトリでアカウントを追加してapplyする
2. `outputs.tf`で出力されたアカウントIDを、`aws-foundation`リポジトリの変数に追加する
3. `aws-foundation`リポジトリでアカウント内のリソースを作成する

### 既存リソースのTerraform移行

既存のOUやアカウントは`terraform import`で状態へ取り込みます。

```bash
cd root-ou
terraform import module.security_ou.aws_organizations_organizational_unit.this ou-xxxxxxxx
terraform import module.security_ou.aws_organizations_account.log_archive 111111111111
```

対象のOU ID、アカウントIDはAWS OrganizationsコンソールまたはAWS CLIで事前に確認し、`terraform plan`で差分がないことを確認します。

### 既存のRoot OUと管理アカウントID

Root OUと管理アカウントはAWS Organizations有効化時に存在するため、Terraformの作成対象ではなく変数として渡します。

```hcl
variable "management_account_id" {
  description = "AWS Organizationsの管理アカウントID"
  type        = string
}

variable "root_ou_id" {
  description = "AWS OrganizationsのRoot OU ID"
  type        = string
}
```

```bash
export TF_VAR_management_account_id="111111111111"
export TF_VAR_root_ou_id="r-xxxxxxxx"
```

## 設計上の注意点

- SCPは管理アカウントには適用されない。管理アカウントはSCPに頼らず、アクセスできるユーザーとロールを最小限に絞る
- SCPとIdentity Center、IAMロール、AWSサービスの権限を組み合わせた際の効果を確認する
- `aws_organizations_policy_attachment`などを変更すると既存のアカウントに影響するため、事前に`terraform plan`で確認する
- SCPは必要な操作が失われないよう、test・developmentのOUで検証してから適用範囲を広げる
- 新しいアカウントやOUは、事前に名前・用途・所有者・環境を定義する
- AWSアカウントは閉鎖すると復旧できない場合があるため、閉鎖前に必要なログの保全を確認する

## 依存関係

- Terraform v1.5以上
- AWS Provider v5系
- AWS Organizationsの管理アカウントの権限

## 実装方針

1. Terraformの基本設定とプロバイダー設定
2. 既存のOU・アカウントのimport
3. SCPの定義と適用
4. タグポリシーの定義と適用
5. IAM Identity Centerのユーザー、グループ、許可セット、割り当て
6. 委任管理者の登録（GuardDuty、Security Hubなど）
