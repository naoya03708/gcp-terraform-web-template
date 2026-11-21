variable "gcp_project_id" {
  description = "GCP プロジェクト ID（公開リポジトリに書かず、TF_VAR_gcp_project_id で渡す）"
  type        = string
}

variable "github_repository" {
  description = "認証を許可する GitHub リポジトリ（OWNER/REPO）。この Workload Identity Pool は、このリポジトリのトークンだけを受け付ける"
  type        = string
  default     = "naoya03708/gcp-terraform-web-template"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository は OWNER/REPO の形式で指定してください。"
  }
}

variable "apply_environments" {
  description = "apply を許可する GitHub Environment 名（Environment 単位で信頼する）"
  type        = list(string)
  default     = ["dev", "prod"]
}

variable "state_bucket" {
  description = "Terraform の state を置く GCS バケット名。指定すると plan 用 SA に、そのバケットのオブジェクト操作（ロックの取得に必要）を付与する。バケットは Terragrunt が最初の apply で作る"
  type        = string
  default     = null
}

variable "apply_roles" {
  description = "apply 用 SA に付与するプロジェクトのロール。構成に必要な範囲に絞っている（オーナー / エディタは使わない）"
  type        = list(string)
  default = [
    "roles/run.admin",
    "roles/cloudsql.admin",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/servicenetworking.networksAdmin",
    "roles/secretmanager.admin",
    "roles/monitoring.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/storage.admin",
  ]
}
