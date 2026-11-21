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

module "cloudrun" {
  source = "./modules/cloudrun"

  name                  = local.name
  region                = var.region
  container_image       = var.container_image
  container_port        = var.container_port
  health_check_path     = var.health_check_path
  cpu                   = var.run_cpu
  memory                = var.run_memory
  min_instances         = var.run_min_instances
  max_instances         = var.run_max_instances
  network               = module.network.network_name
  subnetwork            = module.network.subnet_name
  allow_unauthenticated = var.allow_unauthenticated
  deletion_protection   = var.deletion_protection

  environment = {
    DB_HOST = module.cloudsql.private_ip_address
    DB_PORT = "5432"
    DB_NAME = module.cloudsql.db_name
    DB_USER = module.cloudsql.db_user
  }

  # DB パスワードは Secret Manager のシークレットを、固定バージョンの参照で渡す（平文を持たない）
  secrets = {
    DB_PASSWORD = {
      secret_id = module.cloudsql.password_secret_id
      version   = module.cloudsql.password_secret_version
    }
  }
}

module "monitoring" {
  source = "./modules/monitoring"

  name                     = local.name
  project_id               = var.gcp_project_id
  service_name             = module.cloudrun.service_name
  db_instance_name         = module.cloudsql.instance_name
  slo_availability_target  = var.slo_availability_target
  slo_latency_target       = var.slo_latency_target
  slo_latency_threshold_ms = var.slo_latency_threshold_ms
  alarm_email              = var.alarm_email
}
