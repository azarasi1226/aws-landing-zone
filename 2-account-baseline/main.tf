# 各アカウント内の共通リソースを作成する
# managementの認証情報で実行し、providers.tf の各アカウントのproviderでロールを切り替えて操作する
#
# - log_archive.tf：全アカウントのログを保管するS3バケット（log-archive）
# - config.tf：全アカウントのConfigのレコーダーと、評価結果の集約・組織ルール（audit）
# - cloudtrail.tf：CloudTrailの組織の証跡（management）と、ログを調査するAthena（audit）

module "accounts" {
  source = "./modules/accounts"
}
