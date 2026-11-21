# 0005. Cloud SQL は private IP のみとし、秘密情報は Secret Manager に置く

状態: Proposed

## 背景
DB をインターネットに公開せず、パスワードを、コード・変数・ログに平文で残さずに扱いたい。AWS 版では、RDS の `manage_master_user_password` で、パスワードを state にも残さなかった（AWS 版 ADR 0005）。また、NAT Gateway がコストの最大項目だった（AWS 版 ADR 0004）。

## 決定
- Cloud SQL は **private IP のみ**。private services access で VPC に接続し、Cloud Run は Direct VPC egress で到達する。
- アプリへの秘密情報は、Secret Manager のシークレットを**参照**として注入する。
- Cloud NAT は既定で作らない（`enable_nat = false`）。DB への通信は VPC 内で完結するため、NAT 無しで動く。外部 API を呼ぶ場合のみ有効にする。
- パスワードの生成方式は、**実装時に確認して確定する**: (a) Terraform の `random_password` で生成して Secret Manager に格納、(b) IAM DB 認証でパスワードを持たない。

## 理由
- DB への経路が VPC 内に閉じ、攻撃面が小さい。
- NAT を既定で外すと、AWS 版で最大だったコスト要因を避けられる。

## トレードオフ
- (a) は、パスワードが Terraform の state に残る（AWS 版より弱い）。state バケットのアクセス制御と暗号化で緩和し、README に明記する。(b) は、アプリ側の対応が要る。
- private IP のため、手元からの直接接続には、踏み台や Cloud SQL Auth Proxy 等が要る。
