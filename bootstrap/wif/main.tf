provider "google" {
  project = var.gcp_project_id
}

data "google_project" "this" {
  project_id = var.gcp_project_id
}

locals {
  pool_id = "github-actions"

  # Workload Identity のサブジェクトを、プロジェクト番号つきで組み立てる
  principal_base = "principal://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${local.pool_id}/subject"

  # plan は pull_request のトークン、apply は GitHub Environment のトークンだけを受け付ける
  plan_subject   = "repo:${var.github_repository}:pull_request"
  apply_subjects = [for e in var.apply_environments : "repo:${var.github_repository}:environment:${e}"]
}

resource "google_project_service" "this" {
  for_each = toset([
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = local.pool_id
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.this]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  # 他のリポジトリのトークンは、プール側で拒否する
  attribute_condition = "assertion.repository == \"${var.github_repository}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# --- plan 用: 閲覧のみ。pull_request のトークンだけが使える ---
resource "google_service_account" "plan" {
  account_id   = "gh-tf-plan"
  display_name = "GitHub Actions terraform plan (read-only)"

  depends_on = [google_project_service.this]
}

resource "google_project_iam_member" "plan" {
  for_each = toset(["roles/viewer", "roles/iam.securityReviewer"])

  project = var.gcp_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.plan.email}"
}

# plan でも state のロック取得（オブジェクトの書き込み）が必要
resource "google_storage_bucket_iam_member" "plan_state" {
  count = var.state_bucket != null ? 1 : 0

  bucket = var.state_bucket
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.plan.email}"
}

resource "google_service_account_iam_member" "plan_wif" {
  service_account_id = google_service_account.plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "${local.principal_base}/${local.plan_subject}"

  depends_on = [google_iam_workload_identity_pool.github]
}

# --- apply 用: Environment ごとの承認を通ったジョブだけが使える ---
resource "google_service_account" "apply" {
  account_id   = "gh-tf-apply"
  display_name = "GitHub Actions terraform apply"

  depends_on = [google_project_service.this]
}

resource "google_project_iam_member" "apply" {
  for_each = toset(var.apply_roles)

  project = var.gcp_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.apply.email}"
}

resource "google_service_account_iam_member" "apply_wif" {
  for_each = toset(local.apply_subjects)

  service_account_id = google_service_account.apply.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "${local.principal_base}/${each.value}"

  depends_on = [google_iam_workload_identity_pool.github]
}
