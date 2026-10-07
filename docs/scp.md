# SCP（Service Control Policies）

## 方針

SCPは「許可」ではなく「禁止」を中心に管理し、例外は最小限にします。

## 設定内容

以下の操作を禁止します。

- 組織からの離脱
- CloudTrail、Config、GuardDuty、Security Hubの停止・削除
- 許可リージョン以外の利用
- IAMユーザー・アクセスキーの作成
- 必須タグなしでの主要リソース（EC2、RDSなど）の作成
- rootユーザーの利用

## 対象・集約先

- 対象アカウント：全アカウント
- 集約アカウント：-

## 注意点
