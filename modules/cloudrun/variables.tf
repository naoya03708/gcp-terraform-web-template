variable "name" {
  description = "リソース名のプレフィックス（Cloud Run サービス名にも使う）"
  type        = string
}

variable "region" {
  description = "Cloud Run のリージョン"
  type        = string
}

variable "container_image" {
  description = "デプロイするコンテナイメージ"
  type        = string
}

variable "container_port" {
  description = "コンテナの待受ポート"
  type        = number

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "container_port は 1〜65535 で指定してください。"
  }
}

variable "health_check_path" {
  description = "起動プローブ（HTTP）のパス"
  type        = string
  default     = "/"
}

variable "cpu" {
  description = "インスタンスあたりの CPU（例: \"1\"）"
  type        = string
}

variable "memory" {
  description = "インスタンスあたりのメモリ（例: \"512Mi\"）"
  type        = string
}

variable "min_instances" {
  description = "最小インスタンス数（0 ならリクエストが無い間は課金されない。コールドスタートあり）"
  type        = number

  validation {
    condition     = var.min_instances >= 0
    error_message = "min_instances は 0 以上で指定してください。"
  }
}

variable "max_instances" {
  description = "最大インスタンス数"
  type        = number

  validation {
    condition     = var.max_instances >= 1 && var.max_instances >= var.min_instances
    error_message = "max_instances は 1 以上で、min_instances 以上にしてください。"
  }
}

variable "network" {
  description = "Direct VPC egress で接続する VPC ネットワークの名前"
  type        = string
}

variable "subnetwork" {
  description = "Direct VPC egress で使うサブネットの名前"
  type        = string
}

variable "allow_unauthenticated" {
  description = "true の場合、未認証のアクセスを許可する（allUsers に roles/run.invoker を付与）。組織ポリシーで拒否される場合は false にする"
  type        = bool
  default     = true
}

variable "ingress" {
  description = "受け付けるトラフィックの範囲（LB 経由のみに絞る場合は INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER）"
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"

  validation {
    condition     = contains(["INGRESS_TRAFFIC_ALL", "INGRESS_TRAFFIC_INTERNAL_ONLY", "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"], var.ingress)
    error_message = "ingress は INGRESS_TRAFFIC_ALL / INGRESS_TRAFFIC_INTERNAL_ONLY / INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER のいずれかです。"
  }
}

variable "deletion_protection" {
  description = "true の場合、Terraform からの削除を拒否する（dev は false、prod は true）"
  type        = bool
}

variable "environment" {
  description = "コンテナへ渡す環境変数（平文。秘密情報は secrets を使う）"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secret Manager のシークレットを環境変数として参照で渡す。キーが環境変数名。バージョンは固定する（環境変数は起動時に解決されるため）"
  type = map(object({
    secret_id = string
    version   = string
  }))
  default = {}
}
