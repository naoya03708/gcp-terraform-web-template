# 0005. Cloud SQL は private IP のみとし、秘密情報は Secret Manager に置く

状態: Accepted（dev の apply / destroy は実機で確認済み。destroy は一度で完了せず、手動の対応が要る）

## 背景
DB をインターネットに公開せず、パスワードを、コード・変数・ログに平文で残さずに扱いたい。AWS 版では、RDS の `manage_master_user_password` で、パスワードを state にも残さなかった（AWS 版 ADR 0005）。また、NAT Gateway がコストの最大項目だった（AWS 版 ADR 0004）。

## 決定
- Cloud SQL は **private IP のみ**。private services access で VPC に接続し、Cloud Run は Direct VPC egress で到達する。
- アプリへの秘密情報は、Secret Manager のシークレットを**参照**として注入する。
- Cloud NAT は既定で作らない（`enable_nat = false`）。DB への通信は VPC 内で完結するため、NAT 無しで動く。外部 API を呼ぶ場合のみ有効にする。
- パスワードは、(a) **Terraform の `random_password` で生成して Secret Manager に格納**する（案 (b) の IAM DB 認証は採用しない）。Cloud Run には、固定バージョンのシークレット参照として注入する。実行用の専用 SA に、そのシークレット 1 件の `secretAccessor` だけを付ける。
- Cloud SQL は、`edition = "ENTERPRISE"` を明示する（PostgreSQL 16 以上は、既定が ENTERPRISE_PLUS で、共有コアの tier を拒否するため）。接続は `ENCRYPTED_ONLY`。インスタンス名には、削除後に再利用できないため、ランダムな接尾辞を付ける。

## 理由
- DB への経路が VPC 内に閉じ、攻撃面が小さい。
- NAT を既定で外すと、AWS 版で最大だったコスト要因を避けられる。

## トレードオフ
- (a) は、**パスワードが Terraform の state に残る**（AWS 版より弱い）。state バケットのアクセス制御と暗号化（Google 管理の鍵）で緩和し、README に明記する。plan 用 SA も、state の読み取りができる点に注意する（ADR 0006）。(b) は、アプリ側の対応が要るため採用しなかった。
- **実機で確認済み**（2026-11-24）: dev（`db-f1-micro`、ZONAL）の apply は、Service Networking を含め、一度で成功した（約 13 分）。**destroy は、一度では完了しなかった**: (1) Cloud Run の `serverless-ipv4-…` の予約が残り、サブネットを削除できない（9 時間以内に解消）。(2) Service Networking の接続が、Cloud SQL の削除後も、9 時間以上、`Producer services … still using` で削除できない。Terraform の削除の順序は、正しかった（`module.cloudsql` は `module.network` に依存し、失敗した時点で、state に Cloud SQL は無く、`gcloud sql instances list` も 0 件）。原因は、公式に書かれた**待ち期間**である: Cloud SQL を削除すると、成功は即座に返るが、プロデューサー側のリソースは、**4 日後**に削除され、その間は接続を削除できない（[Configure private services access](https://docs.cloud.google.com/vpc/docs/configure-private-services-access)）。したがって、待ち時間の上限は**最大 4 日**。Compute 側の peering を直接削除する回避策は、公式が勧めていない方法で（"Don't attempt to delete a private connection by deleting its associated VPC Network Peering connection directly"）、dev で 1 回成功しただけである。運用上は、「4 日待つ」を基本とし、直接削除は、Cloud SQL が削除済みの dev に限る。Compute 側の peering（`servicenetworking-googleapis-com`）を直接削除し、`destroy` を再実行すると、残りが全部削除できた。手順は README の「destroy の注意」。
- **未検証**: prod の tier（`db-custom-1-3840`）と REGIONAL の構成。provider の `deletion_policy = "ABANDON"`（接続を削除せずに state から外す）は、試していない。
- private IP のため、手元からの直接接続には、踏み台や Cloud SQL Auth Proxy 等が要る。
