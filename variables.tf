# --- Terragrunt の inputs から注入される値 ---
variable "project" {
  description = "プロジェクト名（リソース名のプレフィックス）"
  type        = string
}

variable "env" {
  description = "環境名（dev / prod）"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env は dev または prod を指定してください。"
  }
}

variable "region" {
  description = "GCP リージョン"
  type        = string
}

variable "gcp_project_id" {
  description = "GCP プロジェクト ID（公開リポジトリに書かず、環境変数 GCP_PROJECT から注入する）"
  type        = string
}

# --- ネットワーク ---
variable "subnet_cidr" {
  description = "Cloud Run（Direct VPC egress）用サブネットの CIDR（/26 以上の大きさ）"
  type        = string
}

variable "enable_nat" {
  description = "true の場合 Cloud NAT を作成する（外部 API 等へのインターネット向け通信が必要な場合のみ）"
  type        = bool
  default     = false
}

# --- Cloud SQL ---
variable "db_name" {
  description = "データベース名"
  type        = string
  default     = "app"
}

variable "db_tier" {
  description = "Cloud SQL のマシンタイプ（ENTERPRISE edition で使えるもの）"
  type        = string
}

variable "db_disk_size_gb" {
  description = "Cloud SQL のディスクサイズ(GB)"
  type        = number
}

variable "db_availability_type" {
  description = "ZONAL（単一ゾーン）または REGIONAL（高可用）"
  type        = string
}

variable "db_point_in_time_recovery" {
  description = "ポイントインタイムリカバリを有効にする（REGIONAL では必須）"
  type        = bool
}

variable "db_backup_retention_days" {
  description = "自動バックアップの保持数"
  type        = number
}

variable "deletion_protection" {
  description = "true の場合、DB の削除を拒否する（dev は false、prod は true）"
  type        = bool
}

# --- Cloud Run ---
variable "container_image" {
  description = "デプロイするコンテナイメージ"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "container_port" {
  description = "コンテナの待受ポート"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "起動プローブ（HTTP）のパス"
  type        = string
  default     = "/"
}

variable "run_cpu" {
  description = "Cloud Run インスタンスあたりの CPU"
  type        = string
}

variable "run_memory" {
  description = "Cloud Run インスタンスあたりのメモリ"
  type        = string
}

variable "run_min_instances" {
  description = "最小インスタンス数（0 で scale-to-zero）"
  type        = number
}

variable "run_max_instances" {
  description = "最大インスタンス数"
  type        = number
}

variable "allow_unauthenticated" {
  description = "true の場合、未認証のアクセスを許可する（Web アプリの公開用）"
  type        = bool
  default     = true
}

# --- 監視（SLO） ---
variable "slo_availability_target" {
  description = "可用性 SLO（30日）。Cloud Monitoring の上限は 0.999"
  type        = number
}

variable "slo_latency_target" {
  description = "レイテンシ SLO の達成割合（0.95 は「95% のリクエストが閾値以内」）"
  type        = number
}

variable "slo_latency_threshold_ms" {
  description = "レイテンシ SLO の閾値(ミリ秒)"
  type        = number
}

variable "alarm_email" {
  description = "アラームの通知先メールアドレス。null の場合は通知チャネルを作らない。リポジトリには書かず、TF_VAR_alarm_email で渡す"
  type        = string
  default     = null
}

# --- 外部 HTTPS LB / Cloud Armor（任意。既定は無効） ---
variable "enable_lb" {
  description = "true の場合、外部 HTTPS LB を作成し、Cloud Run への入口を LB 経由のみに絞る。domain_name が必須（費用が増える）"
  type        = bool
  default     = false
}

variable "enable_armor" {
  description = "true の場合、LB に Cloud Armor（WAF）をアタッチする。enable_lb が true のときだけ有効"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "LB の Google 管理証明書のドメイン名。enable_lb = true のとき必須"
  type        = string
  default     = null

  validation {
    condition     = !var.enable_lb || var.domain_name != null
    error_message = "enable_lb = true の場合は domain_name を指定してください（HTTPS のみ提供するため。ドメインが無い環境では有効化しないでください）。"
  }
}
