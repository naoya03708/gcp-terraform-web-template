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

variable "github_subject_prefix" {
  description = <<-EOT
    GitHub の OIDC トークンの sub クレームの接頭辞。未指定なら `repo:OWNER/REPO`（従来の形式）。
    最近作られたリポジトリは「不変のサブジェクト」が既定で、sub が `repo:OWNER@<オーナー ID>/REPO@<リポジトリ ID>:...` の形になる。
    その場合は、次のコマンドの値を指定する（指定しないと、権限借用が拒否される）:
      gh api repos/OWNER/REPO/actions/oidc/customization/sub --jq .sub_claim_prefix
  EOT
  type        = string
  default     = null
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
