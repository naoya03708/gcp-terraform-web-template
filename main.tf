provider "google" {
  project = var.gcp_project_id
  region  = var.region
}

locals {
  name = "${var.project}-${var.env}"

  # 構成全体で使う API。有効化は無料。destroy で無効化しない（他のリソースや他の用途に影響するため）。
  apis = [
    "compute.googleapis.com",
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "secretmanager.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ]
}

resource "google_project_service" "this" {
  for_each = toset(local.apis)

  service            = each.value
  disable_on_destroy = false
}
