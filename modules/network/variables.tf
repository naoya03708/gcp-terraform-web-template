variable "name" {
  description = "リソース名のプレフィックス"
  type        = string
}

variable "region" {
  description = "サブネット・Cloud NAT を作成するリージョン"
  type        = string
}

variable "subnet_cidr" {
  description = "Cloud Run（Direct VPC egress）が使うサブネットの CIDR。/26 以上（余裕を持って /24 を推奨）"
  type        = string
  default     = "10.0.0.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0)) && tonumber(split("/", var.subnet_cidr)[1]) <= 26
    error_message = "subnet_cidr は有効な CIDR で、プレフィックス長が /26 以下（/26 以上の大きさ）である必要があります。"
  }
}

variable "psa_prefix_length" {
  description = "Cloud SQL 用の private services access に予約する範囲のプレフィックス長（/24 以上の大きさが必要）"
  type        = number
  default     = 20

  validation {
    condition     = var.psa_prefix_length <= 24
    error_message = "psa_prefix_length は 24 以下（/24 以上の大きさ）にしてください。"
  }
}

variable "enable_nat" {
  description = "true の場合 Cloud NAT を作成する（外部 API 等へのインターネット向け通信が必要な場合のみ。既定は無効）"
  type        = bool
  default     = false
}
