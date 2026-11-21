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

module "network" {
  source = "./modules/network"

  name        = local.name
  region      = var.region
  subnet_cidr = var.subnet_cidr
  enable_nat  = var.enable_nat

  depends_on = [google_project_service.this]
}

module "cloudsql" {
  source = "./modules/cloudsql"

  name                   = local.name
  region                 = var.region
  network_id             = module.network.network_id
  tier                   = var.db_tier
  disk_size_gb           = var.db_disk_size_gb
  availability_type      = var.db_availability_type
  point_in_time_recovery = var.db_point_in_time_recovery
  backup_retention_days  = var.db_backup_retention_days
  deletion_protection    = var.deletion_protection
  db_name                = var.db_name

  # private services access の接続ができてから Cloud SQL を作る（destroy では逆順になる）
  depends_on = [module.network]
}
