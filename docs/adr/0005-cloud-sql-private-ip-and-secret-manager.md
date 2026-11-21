# 0005. Cloud SQL は private IP のみとし、秘密情報は Secret Manager に置く

状態: Accepted（Service Networking の destroy の挙動などは実機未検証）

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
- **未検証**: Service Networking の接続は、destroy のときに「producer が使用中」で失敗することがあると報告されている。実機で挙動を確認し、必要なら再実行の手順を README に書く（フェーズ 3）。tier（dev: `db-f1-micro`、prod: `db-custom-1-3840`）の利用可否も、実機で確認する。
- private IP のため、手元からの直接接続には、踏み台や Cloud SQL Auth Proxy 等が要る。
