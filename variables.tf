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
