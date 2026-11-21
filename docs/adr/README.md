# ADR（Architecture Decision Records）

設計上の判断と、その理由・トレードオフの記録です。決定を覆す場合は、既存の ADR を書き換えず、新しい ADR を追加して「Superseded」にします。

状態: `Proposed`（案）/ `Accepted`（決定済み。実機未検証の項目は、各 ADR と README に明記）/ `Superseded`

| # | タイトル | 状態 |
| --- | --- | --- |
| [0001](0001-terragrunt-and-gcs-state.md) | state 管理に Terragrunt と GCS を使う | Accepted |
| [0002](0002-trunk-based-development.md) | トランクベース開発とタグによる prod 昇格 | Accepted |
| [0003](0003-slo-based-alerting-with-native-slo.md) | アラームは SLO ベースにし、ネイティブな SLO を使う | Accepted |
| [0004](0004-compute-cloud-run-then-gke.md) | コンピュートは Cloud Run を先に、GKE Autopilot を後から追加する | Accepted |
| [0005](0005-cloud-sql-private-ip-and-secret-manager.md) | Cloud SQL は private IP のみとし、秘密情報は Secret Manager に置く | Accepted |
| [0006](0006-workload-identity-federation-and-sa-scope.md) | Workload Identity Federation で認証し、apply 用の権限は割り切る | Accepted |
| [0007](0007-compute-switching-variable-vs-separate-root.md) | コンピュートの切り替え方式（変数か、別ルートか） | Proposed |
