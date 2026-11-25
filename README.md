# GCP Terraform Web Template

Google Cloud 上の Web アプリ向けインフラを、Terraform / Terragrunt で再利用できるテンプレートです。[AWS 版](https://github.com/naoya03708/aws-terraform-web-template)の GCP 版にあたります。

> **状態: フェーズ 1（Cloud Run 構成）の実装が完了し、dev を実環境で検証済み（2026-11-24）。** apply、HTTPS、擬似障害でのバーンレートのアラートの発火と復旧、ダッシュボード、CI の WIF 認証と apply、destroy まで確認しました。**prod、外部 LB と Cloud Armor、CI でゼロからの構築は、未検証です。** 検証した範囲と、していない範囲、実機で見つかった問題は、[下の表](#検証状況)に書いています。

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

### destroy の注意

`ENV=dev terragrunt destroy` は、**一度で完了しないことがあります**（実機で確認）。Cloud SQL と Cloud Run は、最初の実行で削除されます。残りは、次のとおりです。

| 症状 | 原因と対処 |
| --- | --- |
| サブネットの削除が `already being used by …serverless-ipv4-cloudrun-…` で失敗 | Cloud Run（Direct VPC egress）が残した内部アドレスの予約が、サービスの削除後もしばらく残る。**時間を置いて**再実行する（今回は、9 時間以内に消えた。App Engine の記載では 1〜2 時間） |
| Service Networking の接続が `Producer services … are still using this connection` で失敗 | Cloud SQL を削除した後も、9 時間以上、削除できなかった。**Terraform の削除の順序の問題ではない**（`module.cloudsql` は `module.network` に依存し、Cloud SQL が先に消えた状態で、接続の削除に失敗した）。**Compute 側の peering を直接削除**してから、再実行する: `gcloud compute networks peerings delete servicenetworking-googleapis-com --network=<VPC 名>`（今回は、これで残り全部が削除できた） |

destroy 後は、Secret Manager、サービスアカウント、Artifact Registry、ログ バケット、LB、静的 IP、予約アドレスが残っていないかを、確認してください。残っていると、課金や、再作成時の衝突の原因になります。残る課金の要因は、ほぼありません（state 用の GCS バケットと、`bootstrap/wif` は、意図して残します）。

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
2. GitHub Secrets に、`GCP_PROJECT`、`GCP_WIF_PROVIDER`、`GCP_PLAN_SA`、`GCP_APPLY_SA` を登録します。**アラームの通知先を CI でも使うなら、`ALARM_EMAIL` も登録します**（任意。未登録だと CI の plan / apply は通知チャネルを作らず、手元で作った場合は、削除の差分が出ます）（公開リポジトリのログに、プロジェクト番号を出さないため、変数ではなく Secrets に置きます）。
3. GitHub Environment（`dev`、`prod`）を作ります。`prod` には、必須レビュアーを設定します。
4. 最初の `terragrunt apply`（state バケットの作成）の後に、`TF_VAR_state_bucket=<バケット名>` を付けて、`bootstrap/wif` を再 apply します。plan 用 SA が、state のロックを取れるようになります。
5. main への自動 apply（dev）を有効にするときは、リポジトリ変数 `AUTO_DEPLOY_DEV=true` を設定します（誤課金を防ぐため、既定は無効）。

## 検証状況

dev 環境を、実際の GCP（無料トライアル、東京）に apply し、擬似障害を起こして destroy するまでを、検証しました（2026-11-24。時刻は UTC）。

| 確認済み | 内容 |
| --- | --- |
| 静的チェック・単体テスト | `terraform fmt` / `validate`、`terragrunt hcl fmt`、tflint、trivy、actionlint、`terraform test` 30 件（モックプロバイダ） |
| state バケット | Terragrunt 0.77.22 が、GCS バケットを自動作成（東京、均一なバケットレベルのアクセス、バージョニング有効）。ADR 0001 |
| apply（手元） | 37 リソース、12:57:43〜13:11:09（約 13 分 26 秒）。Service Networking と Cloud SQL（`db-f1-micro`）を含め、一度で成功 |
| HTTPS | HTTP 200、証明書の検証に成功。150 件のリクエストが、すべて 200（スケールゼロからの 1 回目は 0.42 秒） |
| 擬似障害 | 5xx だけを返す小さなサーバ（公式の `python` イメージ）へ、一時的に差し替え。5xx を 640 件発生 |
| バーンレートのアラート（発火） | 注入の開始から約 5 分後に、4 通のメール（fast: 1h ∧ 5m、slow: 6h ∧ 30m の各 2 条件）が届いた。レイテンシのアラートは、鳴らなかった（想定どおり） |
| バーンレートのアラート（解決） | fast は最後の 5xx の約 14 分後、slow は約 33 分後に、解決のメールが届いた。**長窓が高いままでも、短窓が外れて閉じた**（AND 条件が働いた。ADR 0003） |
| ダッシュボード | API で、全 8 タイルが使うクエリを実行し、実際のリクエストと一致することを確認（達成率 0.4145 = 453 / (453 + 640)、エラーバジェットは負、5xx は 640 件）。AWS 版で出た「障害中も 100%」の不具合は、出なかった。**画面での見た目は、確認していない** |
| CI の WIF 認証（plan） | PR の `terraform-plan`（dev / prod）が、キーなしで成功し、plan が PR コメントに出た |
| CI の WIF 認証と apply（dev） | main へのマージで、`environment: dev` のトークンによる WIF 認証と apply に成功（アラートポリシー 5 件の更新） |
| destroy | 一度では完了しなかった。手順は、[destroy の注意](#destroy-の注意)に書いた |

### 実機で見つかった問題

単体テスト（モック）では、見つからなかったものです。

1. **OIDC の `sub` が「不変のサブジェクト」形式**（`repo:OWNER@<id>/REPO@<id>:…`）で、従来形式の紐づけだと権限借用が拒否された。`github_subject_prefix` で対応（ADR 0006）。
2. **IAM の紐づけを作り直した直後は、反映が遅れる**ことがある。同時に走った 2 つのジョブの片方だけが、1 回目に失敗し、再実行で成功した。
3. Terragrunt は、バケットの存在確認が失敗すると、「無い」とみなして**作成を試みる**。権限の問題でも「bucket 作成の 403」と出て、原因が分かりにくい（最初のエラーを見る）。
4. **プロジェクト番号が、公開の PR コメントとログに出た**（dev の構築後、plan が `projects/<番号>/…` を出力。伏せ字の対象は、プロジェクト ID だけだった）。該当のコメントとログは削除し、番号も伏せ字にするよう修正した。
5. **ダッシュボードが、plan のたびに「更新」になった**。API が返す形（0 の位置指定は省略、`targetAxis` の既定値）と、定義が違ったため。定義を合わせて解消。
6. **CI にメールアドレスが渡らず、通知チャネルの削除が失敗**した（削除が、チャネルを参照するアラートポリシーの更新より先に走る）。任意の Secrets `ALARM_EMAIL` を、CI の plan / apply にも渡す形に修正。
7. **通知の件名から、緊急かチケットかが分からず、重大度も無かった**。条件名に `[page]` / `[ticket]` を付け、`severity` を設定した。
8. **destroy が、一度で完了しない**（Cloud Run のサブネットのアドレスの解放待ち、Service Networking の接続の削除の失敗）。

| 未検証 | 理由・備考 |
| --- | --- |
| CI でゼロから 37 リソースを apply（apply 用 SA のロールが足りるか） | 手元の apply は、自分の権限で行った。CI の apply は、更新の 5 件だけ確認した |
| prod 環境（Cloud SQL の高可用、常時 1 台の Cloud Run、`db-custom-1-3840`） | 実環境で未確認 |
| 外部 HTTPS LB と Cloud Armor | ドメインを持っていないため、**実機検証の予定なし** |
| ダッシュボードの画面での見た目 | API でクエリと数値のみ確認 |
| 費用の実績 | 請求への反映を待って、`docs/cost.md` に記録する |

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
| 3 | 実機検証と実績の記録 | 一部完了（dev を検証。prod・LB は未検証、費用の実績は記録待ち） |

## ライセンス
MIT
