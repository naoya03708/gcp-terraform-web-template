variable "name" {
  description = "リソース名のプレフィックス"
  type        = string
}

variable "region" {
  description = "Cloud SQL のリージョン"
  type        = string
}

variable "network_id" {
  description = "private IP で接続する VPC ネットワークの ID（呼び出し側で private services access の接続に依存させること）"
  type        = string
}

variable "database_version" {
  description = "PostgreSQL のバージョン"
  type        = string
  default     = "POSTGRES_16"
}

variable "tier" {
  description = "マシンタイプ（dev は共有コアの db-f1-micro など。ENTERPRISE edition で使えるもの）"
  type        = string
}

variable "disk_size_gb" {
  description = "ディスクサイズ(GB)。自動拡張は有効"
  type        = number
}

variable "availability_type" {
  description = "ZONAL（単一ゾーン）または REGIONAL（高可用）"
  type        = string

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "availability_type は ZONAL または REGIONAL を指定してください。"
  }
}

variable "point_in_time_recovery" {
  description = "ポイントインタイムリカバリを有効にする（REGIONAL では必須）"
  type        = bool
}

variable "backup_retention_days" {
  description = "自動バックアップの保持数（日数）"
  type        = number
}

variable "deletion_protection" {
  description = "true の場合、Terraform からの削除を拒否する（dev は false、prod は true）"
  type        = bool
}

variable "db_name" {
  description = "作成するデータベース名"
  type        = string
  default     = "app"
}

variable "db_user" {
  description = "アプリ用のデータベースユーザー名"
  type        = string
  default     = "app"
}
