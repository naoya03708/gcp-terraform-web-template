variable "name" {
  description = "リソース名のプレフィックス"
  type        = string
}

variable "project_id" {
  description = "GCP プロジェクト ID（Cloud SQL のメトリクスの絞り込みに使う）"
  type        = string
}

variable "service_name" {
  description = "監視対象の Cloud Run サービス名"
  type        = string
}

variable "db_instance_name" {
  description = "監視対象の Cloud SQL インスタンス名"
  type        = string
}

variable "slo_availability_target" {
  description = "可用性 SLO（30日）。Cloud Monitoring の SLO の上限は 0.999"
  type        = number

  validation {
    condition     = var.slo_availability_target > 0 && var.slo_availability_target <= 0.999
    error_message = "slo_availability_target は 0 より大きく 0.999 以下で指定してください（Cloud Monitoring の SLO の上限）。"
  }
}

variable "slo_latency_target" {
  description = "レイテンシ SLO の達成割合（例: 0.95 は「95% のリクエストが閾値以内」）"
  type        = number

  validation {
    condition     = var.slo_latency_target > 0 && var.slo_latency_target <= 0.999
    error_message = "slo_latency_target は 0 より大きく 0.999 以下で指定してください。"
  }
}

variable "slo_latency_threshold_ms" {
  description = "レイテンシ SLO の閾値(ミリ秒)"
  type        = number

  validation {
    condition     = var.slo_latency_threshold_ms > 0
    error_message = "slo_latency_threshold_ms は正の値で指定してください。"
  }
}

variable "slo_rolling_period_days" {
  description = "SLO の評価期間（日）。Cloud Monitoring の上限は 30"
  type        = number
  default     = 30

  validation {
    condition     = var.slo_rolling_period_days >= 1 && var.slo_rolling_period_days <= 30
    error_message = "slo_rolling_period_days は 1〜30 で指定してください。"
  }
}

variable "db_disk_utilization_threshold" {
  description = "Cloud SQL のディスク使用率の閾値（0〜1）。唯一の原因系アラーム"
  type        = number
  default     = 0.85

  validation {
    condition     = var.db_disk_utilization_threshold > 0 && var.db_disk_utilization_threshold < 1
    error_message = "db_disk_utilization_threshold は 0 より大きく 1 より小さい値で指定してください。"
  }
}

variable "alarm_email" {
  description = "アラームの通知先メールアドレス。null の場合は通知チャネルを作らない（リポジトリには書かず、実行時に渡す）"
  type        = string
  default     = null
}
