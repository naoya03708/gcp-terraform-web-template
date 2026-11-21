# 0006. Workload Identity Federation で認証し、apply 用の権限は割り切る

状態: Proposed

## 背景
CI から GCP を操作するために、サービスアカウントの長期キーを GitHub Secrets に置くと、漏洩時の影響が大きい。AWS 版では GitHub OIDC を使ったが、検証用アカウントの組織の SCP が OIDC プロバイダの作成を拒否し、実機では未検証になった（AWS 版 ADR 0006）。

## 決定
- GitHub Actions の OIDC を信頼する Workload Identity Federation を使う。**サービスアカウントの長期キーは作らない**。
- サービスアカウントを2つに分ける。
  - plan 用: 閲覧権限 + state バケットの読み書き。信頼条件は、本リポジトリの `pull_request` のみ。fork からの PR には権限を渡さない。
  - apply 用: GitHub Environment（`dev` / `prod`）のジョブのみ。権限は、デモ用途では広めにし、実運用での絞り込みを推奨する。
- WIF のリソースは、別ルートモジュール（`bootstrap/wif`）で、初回のみ手動 apply する。

## 理由
- 一時的な認証情報なので、キーの漏洩・保管・ローテーションの問題がない。
- plan（レビュー前に誰でも走る）と apply（承認後のみ）で、権限を分離できる。

## トレードオフ
- apply 用 SA の権限は広い。実運用では、サービス別のロールや、カスタムロールへの絞り込みを推奨する。引き受け条件を Environment に限定して、リスクを抑える。
- **前提確認（実施済み）**: 検証用アカウントには、Google が自動で作成した組織があり、組織レベルの Org Policy が設定されていた。設計に関わる確認結果は次のとおり。AWS 版のように、組織の統制で作成が拒否された場合は、未検証として、理由を README に記録する。

| 制約 | 状態 | 影響 |
| --- | --- | --- |
| `iam.allowedPolicyMemberDomains` | 全許可（有効な設定） | Cloud Run の未認証公開は可能 |
| `iam.disableServiceAccountKeyCreation` / `...KeyUpload` | 有効 | サービスアカウントの長期キーを作れない。本 ADR の方針と一致 |
| `iam.automaticIamGrantsForDefaultServiceAccounts` | 有効 | 既定の SA に自動で権限が付かない。専用 SA に明示的に権限を付ける設計で対応 |
| `storage.uniformBucketLevelAccess` | 有効 | state バケットを、均一なバケットレベルのアクセスで作る必要がある（ADR 0001） |
| `compute.restrictProtocolForwardingCreationForTypes` | 許可リストあり | 外部 LB への影響は、実装時に確認 |

組織レベルのみを確認した。フォルダ・プロジェクトでの上書きは、プロジェクト作成後に、有効な設定を確認する。
