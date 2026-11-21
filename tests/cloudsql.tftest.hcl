mock_provider "google" {}

run "dev_zonal" {
  command = plan

  module {
    source = "./modules/cloudsql"
  }

  variables {
    name                   = "test"
    region                 = "asia-northeast1"
    network_id             = "projects/p/global/networks/n"
    tier                   = "db-f1-micro"
    disk_size_gb           = 10
    availability_type      = "ZONAL"
    point_in_time_recovery = false
    backup_retention_days  = 3
    deletion_protection    = false
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].edition == "ENTERPRISE"
    error_message = "共有コアの tier を使えるよう、edition は ENTERPRISE を明示すること"
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].ip_configuration[0].ipv4_enabled == false
    error_message = "パブリック IP を付けないこと"
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].ip_configuration[0].ssl_mode == "ENCRYPTED_ONLY"
    error_message = "暗号化された接続のみを許可すること"
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].availability_type == "ZONAL"
    error_message = "dev は単一ゾーンであること"
  }

  assert {
    condition     = google_sql_database_instance.this.deletion_protection == false
    error_message = "dev は削除保護なしであること（destroy で消せる）"
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].backup_configuration[0].enabled == true
    error_message = "自動バックアップが有効であること"
  }

  assert {
    condition     = google_secret_manager_secret.db_password.secret_id == "test-db-password"
    error_message = "DB パスワードが Secret Manager のシークレットとして作られること"
  }
}

run "prod_regional_protected" {
  command = plan

  module {
    source = "./modules/cloudsql"
  }

  variables {
    name                   = "test"
    region                 = "asia-northeast1"
    network_id             = "projects/p/global/networks/n"
    tier                   = "db-custom-1-3840"
    disk_size_gb           = 20
    availability_type      = "REGIONAL"
    point_in_time_recovery = true
    backup_retention_days  = 7
    deletion_protection    = true
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].availability_type == "REGIONAL"
    error_message = "prod は高可用（REGIONAL）であること"
  }

  assert {
    condition     = google_sql_database_instance.this.deletion_protection == true
    error_message = "prod は削除保護ありであること"
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].backup_configuration[0].point_in_time_recovery_enabled == true
    error_message = "prod はポイントインタイムリカバリが有効であること"
  }
}

run "regional_requires_pitr" {
  command = plan

  module {
    source = "./modules/cloudsql"
  }

  variables {
    name                   = "test"
    region                 = "asia-northeast1"
    network_id             = "projects/p/global/networks/n"
    tier                   = "db-custom-1-3840"
    disk_size_gb           = 20
    availability_type      = "REGIONAL"
    point_in_time_recovery = false
    backup_retention_days  = 7
    deletion_protection    = true
  }

  expect_failures = [google_sql_database_instance.this]
}

run "rejects_invalid_availability_type" {
  command = plan

  module {
    source = "./modules/cloudsql"
  }

  variables {
    name                   = "test"
    region                 = "asia-northeast1"
    network_id             = "projects/p/global/networks/n"
    tier                   = "db-f1-micro"
    disk_size_gb           = 10
    availability_type      = "MULTI"
    point_in_time_recovery = false
    backup_retention_days  = 3
    deletion_protection    = false
  }

  expect_failures = [var.availability_type]
}
