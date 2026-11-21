variable "name" {
  description = "リソース名のプレフィックス"
  type        = string
}

variable "region" {
  description = "Cloud Run のリージョン（serverless NEG を作るリージョン）"
  type        = string
}

variable "service_name" {
  description = "LB のバックエンドにする Cloud Run サービス名"
  type        = string
}

variable "domain_name" {
  description = "Google 管理の証明書を発行するドメイン名。DNS の A レコードを、出力 lb_ip_address に向ける必要がある（証明書の発行は、DNS が向いてから）"
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "domain_name は、小文字の有効なドメイン名で指定してください。"
  }
}

variable "enable_armor" {
  description = "true の場合、Cloud Armor のセキュリティポリシー（事前定義の WAF ルール）をバックエンドにアタッチする"
  type        = bool
  default     = true
}
