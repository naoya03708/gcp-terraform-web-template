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
