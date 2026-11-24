# 0006. Workload Identity Federation で認証し、apply 用の権限は割り切る

状態: Accepted（plan 用の WIF 認証は実機で確認済み。apply 用（Environment 経由）は未検証）

## 背景
CI から GCP を操作するために、サービスアカウントの長期キーを GitHub Secrets に置くと、漏洩時の影響が大きい。AWS 版では GitHub OIDC を使ったが、検証用アカウントの組織の SCP が OIDC プロバイダの作成を拒否し、実機では未検証になった（AWS 版 ADR 0006）。

## 決定
- GitHub Actions の OIDC を信頼する Workload Identity Federation を使う。**サービスアカウントの長期キーは作らない**。
- サービスアカウントを2つに分ける。
  - plan 用: プロジェクトの閲覧（`roles/viewer`、`roles/iam.securityReviewer`）+ state バケットのオブジェクト操作（ロック取得のため）。信頼条件は、本リポジトリの `pull_request` のみ。fork からの PR には権限を渡さない。
  - apply 用: GitHub Environment（`dev` / `prod`）のジョブのみ。ロールは、構成に必要なサービスの管理者ロール（Cloud Run、Cloud SQL、ネットワーク、Secret Manager、監視など）に絞り、**オーナー / エディタは付けない**。それでも広いので、実運用での絞り込みを推奨する。
- **GitHub の OIDC の `sub` の形式に注意する（実機で見つかった不具合）**: 最近作られたリポジトリは、`sub` が「不変のサブジェクト」形式（`repo:OWNER@<オーナー ID>/REPO@<リポジトリ ID>:pull_request`）になる。従来形式（`repo:OWNER/REPO:pull_request`）の紐づけだと、STS のトークン交換は通るが、サービスアカウントの権限借用が `iam.serviceAccounts.getAccessToken` で拒否される。`bootstrap/wif` は、変数 `github_subject_prefix`（既定は従来形式）で切り替え、値は `gh api repos/OWNER/REPO/actions/oidc/customization/sub --jq .sub_claim_prefix` で取得する。プロバイダの `attribute_condition`（`assertion.repository`）は、影響を受けない。
- プールのプロバイダは、`attribute_condition` で、本リポジトリのトークンだけを受け付ける。プロバイダ名・SA の値は、プロジェクト番号を含むため、リポジトリ変数ではなく **GitHub Secrets** に置く。plan の結果を PR コメントに出すときは、プロジェクト ID を伏せ字にする。
- WIF のリソースは、別ルートモジュール（`bootstrap/wif`）で、初回のみ手動 apply する。

## 理由
- 一時的な認証情報なので、キーの漏洩・保管・ローテーションの問題がない。
- plan（レビュー前に誰でも走る）と apply（承認後のみ）で、権限を分離できる。

## トレードオフ
- apply 用 SA の権限は広い。実運用では、サービス別のロールや、カスタムロールへの絞り込みを推奨する。引き受け条件を Environment に限定して、リスクを抑える。
- plan 用 SA は、クラウドのリソースには閲覧のみだが、**state バケットを読める**。state には DB のパスワードが残る（ADR 0005）ため、plan の信頼範囲は、同じリポジトリの PR（fork 除外）に限っている。
- **実機で確認済み**: PR の plan（`pull_request` のトークン）による認証。AWS 版と違い、GCP の検証用組織には WIF を止める制約が無く、実際に認証できた。
- **未検証**: apply 用 SA での認証（GitHub Environment のトークン）。dev の apply の際に確認する。
- IAM の紐づけを作り直した直後は、反映が遅れて、権限借用が一時的に拒否されることがある（同時に走った 2 つのジョブの片方だけが、1 回目に失敗し、再実行で成功した）。
- **前提確認（実施済み）**: 検証用アカウントには、Google が自動で作成した組織があり、組織レベルの Org Policy が設定されていた。設計に関わる確認結果は次のとおり。AWS 版のように、組織の統制で作成が拒否された場合は、未検証として、理由を README に記録する。

| 制約 | 状態 | 影響 |
| --- | --- | --- |
| `iam.allowedPolicyMemberDomains` | 全許可（有効な設定） | Cloud Run の未認証公開は可能 |
| `iam.disableServiceAccountKeyCreation` / `...KeyUpload` | 有効 | サービスアカウントの長期キーを作れない。本 ADR の方針と一致 |
| `iam.automaticIamGrantsForDefaultServiceAccounts` | 有効 | 既定の SA に自動で権限が付かない。専用 SA に明示的に権限を付ける設計で対応 |
| `storage.uniformBucketLevelAccess` | 有効 | state バケットを、均一なバケットレベルのアクセスで作る必要がある（ADR 0001） |
| `compute.restrictProtocolForwardingCreationForTypes` | 許可リストあり | 外部 LB への影響は、実装時に確認 |

組織レベルのみを確認した。フォルダ・プロジェクトでの上書きは、プロジェクト作成後に、有効な設定を確認する。
