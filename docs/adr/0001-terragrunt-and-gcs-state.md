# 0001. state 管理に Terragrunt と GCS を使う

状態: Accepted（Terragrunt 0.77.22 での GCS バケットの自動作成は、実機で確認済み）

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
- 検証用の組織には `storage.uniformBucketLevelAccess` が有効なので、`remote_state` の `enable_bucket_policy_only = true` で、均一なバケットレベルのアクセスのバケットを作る（既定は false。ADR 0006 の確認結果）。
- **実機で確認済み**: 参照した公式ドキュメントは Terragrunt 1.x 系のものだったが、AWS 版と揃えて固定した 0.77.22 でも、`terragrunt plan` の初回に、state 用バケットが自動作成された。作成されたバケットは、東京（`ASIA-NORTHEAST1`）、均一なバケットレベルのアクセス有効、バージョニング有効だった（`gcloud storage buckets describe` で確認）。バージョン固定の見直しは不要。
- plan 用 SA は、state のロック取得のためにバケットへの書き込みが要る。バケットは最初の apply で Terragrunt が作るため、plan 用 SA へのバケット権限は、最初の apply の後に、`bootstrap/wif` を再 apply して付与する（README 参照）。
