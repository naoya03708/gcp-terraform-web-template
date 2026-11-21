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
