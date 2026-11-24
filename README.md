# GCP Terraform Web Template

Google Cloud 上の Web アプリ向けインフラを、Terraform / Terragrunt で再利用できるテンプレートです。[AWS 版](https://github.com/naoya03708/aws-terraform-web-template)の GCP 版にあたります。

> **状態: フェーズ 1（Cloud Run 構成）の実装が完了。実機検証は、一部のみ実施（アプリ本体の apply は未実施）。** CI（fmt / validate / lint / セキュリティスキャン / `terraform test` 29 件）は通っています。実機では、state バケットの作成、実環境に対する plan、WIF の bootstrap の apply、**PR の plan による CI の WIF 認証**を確認しました。検証した範囲と、していない範囲は、[下の表](#検証状況)に明記しています。

## 構成

Cloud Run + Cloud SQL（PostgreSQL、private IP のみ）+ VPC + SLO ベースの監視。任意で、外部 HTTPS LB と Cloud Armor。

| 項目 | 内容 |
| --- | --- |
| ネットワーク | カスタム VPC、Cloud Run 用サブネット（Direct VPC egress）、Cloud SQL 用の private services access。Cloud NAT は既定で作らない |
| コンピュート | Cloud Run（専用サービスアカウント、起動プローブ、scale-to-zero 対応）。URL は `*.run.app`（HTTPS） |
| DB | Cloud SQL for PostgreSQL 16（private IP のみ、暗号化接続のみ）。パスワードは Terraform で生成して Secret Manager に格納し、Cloud Run に参照で注入 |
| 監視 | Cloud Monitoring の SLO（可用性 99.5%、レイテンシ「500ms 以内が 95%」）、バーンレートのアラート（緊急 / チケット）、ダッシュボード。原因系のアラームは、DB のディスクだけ |
| CI/CD | GitHub Actions（fmt / validate / lint / trivy / test、PR で plan、main→dev、タグ→prod）。認証は Workload Identity Federation（長期キーなし） |
| 任意機能 | 外部 HTTPS LB + Cloud Armor（`enable_lb`、既定は無効。ドメインが必要） |

GKE Autopilot は、第 2 段階として追加する予定です（未着手）。

## ドキュメント

| 文書 | 内容 |
| --- | --- |
| [docs/requirements.md](docs/requirements.md) | 要件定義（スコープ、要件、受け入れ基準、AWS 版からの教訓） |
| [docs/design.md](docs/design.md) | 基本設計（構成図、モジュール、セキュリティ、検証計画） |
| [docs/adr/](docs/adr/) | 設計判断の記録（7 件） |
| [docs/slo.md](docs/slo.md) | SLO の定義と、アラームごとの一次対応（runbook） |
| [docs/cost.md](docs/cost.md) | 費用の要因（金額は未確認。実績はフェーズ 3 で記録） |

## 使い方

前提: 課金が有効な GCP プロジェクト、[devcontainer](.devcontainer/devcontainer.json)（terraform / terragrunt / tflint / gcloud が入ります）。

```bash
gcloud auth application-default login      # ローカルの認証（長期キーは使わない）
export GCP_PROJECT=<your-gcp-project-id>   # 必須。リポジトリには書かない
export TF_VAR_alarm_email=<you@example.com> # 任意。未設定なら通知チャネルを作らない

ENV=dev terragrunt plan                    # dev.tfvars を使用
ENV=dev terragrunt apply                   # state 用の GCS バケットは、初回に自動で作られる
ENV=dev terragrunt destroy                 # 検証が終わったら、必ず削除する
```

- リージョンは `GCP_REGION` で変更できます（既定: `asia-northeast1`）。
- 環境の差分は、`dev.tfvars` / `prod.tfvars` だけです。
- prod は、CI の承認ゲート（タグ `v*` と GitHub Environment）で apply する想定です。

### CI の設定（Workload Identity Federation）

1. 初回のみ、手元から `bootstrap/wif` を apply します（ローカル state）。

   ```bash
   cd bootstrap/wif
   export TF_VAR_gcp_project_id=$GCP_PROJECT
   # 最近作られたリポジトリは OIDC の sub が「不変のサブジェクト」形式。API の値を渡す（ADR 0006）
   export TF_VAR_github_subject_prefix=$(gh api repos/<OWNER>/<REPO>/actions/oidc/customization/sub --jq .sub_claim_prefix)
   terraform init && terraform apply
   terraform output -raw workload_identity_provider   # 値は GitHub Secrets に登録する
   ```
2. GitHub Secrets に、`GCP_PROJECT`、`GCP_WIF_PROVIDER`、`GCP_PLAN_SA`、`GCP_APPLY_SA` を登録します（公開リポジトリのログに、プロジェクト番号を出さないため、変数ではなく Secrets に置きます）。
3. GitHub Environment（`dev`、`prod`）を作ります。`prod` には、必須レビュアーを設定します。
4. 最初の `terragrunt apply`（state バケットの作成）の後に、`TF_VAR_state_bucket=<バケット名>` を付けて、`bootstrap/wif` を再 apply します。plan 用 SA が、state のロックを取れるようになります。
5. main への自動 apply（dev）を有効にするときは、リポジトリ変数 `AUTO_DEPLOY_DEV=true` を設定します（誤課金を防ぐため、既定は無効）。

## 検証状況

**dev 環境の apply / destroy は、まだ行っていません。** ここまでに確認できたのは、次の範囲です。

| 確認済み（CI / ローカル） | 内容 |
| --- | --- |
| 静的チェック | `terraform fmt` / `validate`、`terragrunt hcl fmt`、tflint（google ルールセット）、trivy、actionlint |
| 単体テスト | `terraform test` 29 件（モックプロバイダ）。dev / prod の差、不正値の拒否、任意機能のフラグなど |
| 実機: state バケット | `terragrunt plan` で、state 用の GCS バケットが自動作成された。東京、均一なバケットレベルのアクセス、バージョニング有効（Terragrunt 0.77.22）。ADR 0001 |
| 実機: plan | 実プロジェクトに対する `terragrunt plan`（dev）が、37 リソースの追加として成功（provider の引数エラーなし。リソースは作成していない） |
| 実機: WIF の bootstrap | `bootstrap/wif` の apply が成功（25 リソース）。組織ポリシーに阻まれずに、WIF のプール・プロバイダ・SA を作成できた |
| 実機: CI の WIF 認証（plan） | PR の `terraform-plan`（dev / prod）が、キーなしの認証で成功し、plan 結果が PR コメントに出た（CI では `alarm_email` が未設定のため、35 リソース）。コメントに、プロジェクト ID・番号・メールが出ていないことも確認した。**apply 用 SA（Environment 経由）での認証は未確認** |

実機で見つかった問題と、わかったこと:

- **OIDC の `sub` が「不変のサブジェクト」形式**（`repo:OWNER@<id>/REPO@<id>:…`）で、従来形式の紐づけだと権限借用が拒否された。`github_subject_prefix` で対応（ADR 0006）。モックのテストでは見つからなかった。
- **IAM の紐づけを作り直した直後は、反映が遅れる**ことがある。同時に走った prod の plan だけが、1 回目に失敗し、再実行で成功した。
- Terragrunt は、バケットの存在確認が失敗すると、「バケットが無い」とみなして**作成を試みる**。plan 用 SA には作成権限が無いため、権限の問題でも「bucket 作成の 403」というエラーになり、原因が分かりにくい（最初のエラーを見る）。

| 未検証（実機で確認が要る） | 理由・備考 |
| --- | --- |
| apply / destroy 全体、HTTPS での応答 | 未実施（フェーズ 3） |
| Service Networking 接続の destroy | 「producer が使用中」で失敗する報告がある（ADR 0005） |
| Cloud SQL の tier（dev: `db-f1-micro`、prod: `db-custom-1-3840`） | 利用可否を、実機で確認する |
| SLO のフィルタ、長窓 ∧ 短窓の AND のバーンレートのアラートの発火と復旧 | 公式の例に無い書き方（ADR 0003） |
| ダッシュボードのタイル | 単体テストで検証できない。AWS 版では、実機でしか見つからない不具合があった |
| apply 用 SA（GitHub Environment 経由）での WIF 認証、main→dev の自動デプロイ | Environment の作成と、dev の apply の際に確認する（ADR 0006） |
| 外部 HTTPS LB と Cloud Armor | ドメインを持っていないため、**実機検証の予定なし** |
| prod 環境、メール通知 | 実機で未確認 |

## 注意事項

- **DB のパスワードは、Terraform の state に残ります**（`random_password`）。state バケットのアクセス制御と暗号化で守っています。plan 用の SA も、state を読めます（ADR 0005 / 0006）。
- devcontainer の `gcloud` は、**サードパーティの feature**（`ghcr.io/dhoeric/features/google-cloud-cli`）です。ビルド時に、その提供元のコードが実行されます。
- provider の lock ファイル（`.terraform.lock.hcl`、ルートと `bootstrap/wif`）をコミットしています（linux / darwin の amd64・arm64 のハッシュ入り）。provider を更新するときは、Dependabot の PR で、lock も更新されることを確認してください。
- apply 用のサービスアカウントのロールは、広めです（オーナー / エディタは付けていません）。実運用では絞り込んでください（ADR 0006）。
- 公開リポジトリのため、プロジェクト ID、メールアドレスなどは、コードに書かず、環境変数と GitHub Secrets で渡します。

## フェーズ

| フェーズ | 内容 | 状態 |
| --- | --- | --- |
| 0 | 要件定義・基本設計 | 完了 |
| 1 | Cloud Run 構成の実装 | 完了（実機未検証） |
| 2 | GKE Autopilot の追加 | 未着手 |
| 3 | 実機検証と実績の記録 | 未着手 |

## ライセンス
MIT
