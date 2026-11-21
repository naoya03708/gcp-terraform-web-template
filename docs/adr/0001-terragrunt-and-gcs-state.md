# 0001. state 管理に Terragrunt と GCS を使う

状態: Proposed

## 背景
state をクラウドのバケットに置く場合、バケットを事前に作る手間（鶏と卵問題）がある。テンプレートを clone してすぐ試せることを重視したい。AWS 版では、Terragrunt でバケットを自動作成し、S3 のネイティブロックを使った（AWS 版 ADR 0001）。

## 決定
- Terragrunt の `remote_state`（`gcs`）で、state 用バケットを自動作成する。バージョニングを有効にする。
- GCS バックエンドは、書き込みの排他制御（ロック）を、バケット内のロックオブジェクトで行う。DynamoDB 相当の別リソースは要らない。
- 環境は `ENV` 環境変数で切り替え、差分は直下の `dev.tfvars` / `prod.tfvars` で表現する。state の prefix は `<env>`。
- バケット名は `<project>-tfstate-<project_id>` 形式とし、プロジェクト ID はコードに書かず、実行時に取得または環境変数で渡す。

## 理由
- 事前作成の手順がなくなり、README の手順が短くなる。
- AWS 版と同じ構成になり、2つのテンプレートの差が、クラウド固有の部分に集中する。

## トレードオフ
- Terragrunt への依存が増える（CI・devcontainer にも導入が必要）。
- 環境の切り替えが `ENV` の指定に依存する。prod の apply は、CI の承認ゲート経由に限定して緩和する（ADR 0002）。
- 実装時に確認: Terragrunt の GCS バケット自動作成の挙動（ロケーション、バージョニング、アクセス制御）。検証用の組織には `storage.uniformBucketLevelAccess` が有効なので、バケットを均一なバケットレベルのアクセスで作る設定（Terragrunt の `enable_bucket_policy_only` 相当）が必要になる見込み（ADR 0006 の確認結果）。
