# AWS Landing Zone

AWS Organizationsの構成（OU、アカウント、SCP）と、IAM Identity Centerによる各アカウントへのアクセス、各アカウント内の共通リソース（ログ基盤、セキュリティ監視、ガバナンスなど）を管理するリポジトリです。

[📚 ドキュメントサイト](https://azarasi1226.github.io/aws-landing-zone/)

- `1-organization/`：組織の構成とアクセス管理
- `2-account-baseline/`：各アカウント内の共通リソース

`1-organization/`と`2-account-baseline/`は、それぞれ別のstateを持ち、この順にapplyします。分けている理由、各アカウントへの入り方、アカウント追加の手順は[Terraformの構成のドキュメント](https://azarasi1226.github.io/aws-landing-zone/terraform.html)にまとめています。

## 初期構築

環境ごとに1回だけ行います。作業はVS Codeの「Dev Containers: Reopen in Container」で開いたdev containerの中で行います（Terraformのバージョンは`.devcontainer/devcontainer.json`で固定）。

### 1. 手動で準備する

以下はTerraformでは作成しないため、コンソールで用意します。

1. management accountで、AWS Organizationsを有効化する（Root OUは自動で作成される）
2. IAM Identity Centerを組織インスタンスとして有効化し、Terraform実行者に管理者権限（`AdministratorAccess`）の許可セットを割り当てる
3. Terraformのstateを保存するS3バケットを作成する
4. 組織に招待で参加させたアカウントがある場合は、そのアカウントに`OrganizationAccountAccessRole`を作成する（Organizationsで作成したアカウントには自動で作られる）

> Terraform実行者への管理者権限の割り当ては、設定ミスで自分が締め出されないよう、Terraformでは管理せず手動のまま残します。PowerUserなど、IAMやOrganizationsを操作できない権限では実行できません。

### 2. 1-organization/を適用する

```bash
cd 1-organization
cp backend.hcl.example backend.hcl            # stateのS3バケットを設定
cp terraform.tfvars.example terraform.tfvars  # アカウントのメールアドレスを設定
cp imports.tf.example imports.tf              # 既存の組織・OU・アカウントのIDを設定

export AWS_PROFILE=<managementの管理者プロファイル>
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
rm imports.tf                                 # 取り込みが終わったら削除する
```

- `imports.tf`には、既にある組織・OU・アカウントのIDを書きます。組織は必須で、OUとアカウントは既にあるものだけを書きます。まだないものは、applyで新しく作られます
- 既にあるアカウントの`terraform.tfvars`のメールアドレスは、実際の値と1文字も違わないようにします。違うとアカウントの作り直しになり、`prevent_destroy`でplanがエラーになります
- applyの前に、planに`destroy`や`replace`がないことを確認します。そのほかの確認点は[AWS Organizationsのドキュメント](https://azarasi1226.github.io/aws-landing-zone/organizations.html)にまとめています
- 作成した直後のauditアカウントを、GuardDuty・Security Hubの委任管理者に登録するところで、エラーになることがあります。数分待ってからもう一度applyすると成功します

### 3. 2-account-baseline/を適用する

```bash
cd 2-account-baseline
cp backend.hcl.example backend.hcl            # stateのS3バケットを設定

terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
```

既にConfigを使っているアカウントがある場合は、[AWS Configのドキュメント](https://azarasi1226.github.io/aws-landing-zone/config.html)を参照してください。

## 日常の運用

変更するディレクトリで、planで差分を確認してからapplyします。

```bash
export AWS_PROFILE=<managementの管理者プロファイル>
terraform plan -out=tfplan
terraform apply tfplan
```

`backend.hcl`と`terraform.tfvars`はGit管理外のため、新しい環境で作業するときは、初期構築と同じく`.example`からコピーして作成します。
