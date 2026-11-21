# Cloud SQL のインスタンス名は、削除後しばらく再利用できない。destroy → apply を繰り返せるよう接尾辞を付ける。
resource "random_id" "suffix" {
  byte_length = 3
}

resource "google_sql_database_instance" "this" {
  name                = "${var.name}-${random_id.suffix.hex}"
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    tier = var.tier
    # PostgreSQL 16 以上は edition の既定が ENTERPRISE_PLUS で、共有コアの tier を拒否するため明示する。
    edition           = "ENTERPRISE"
    availability_type = var.availability_type
    disk_size         = var.disk_size_gb
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    ip_configuration {
      # パブリック IP は付けない。VPC 内の private IP でのみ接続する。
      ipv4_enabled    = false
      private_network = var.network_id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = var.point_in_time_recovery

      backup_retention_settings {
        retained_backups = var.backup_retention_days
      }
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }
  }

  lifecycle {
    precondition {
      condition     = var.availability_type != "REGIONAL" || var.point_in_time_recovery
      error_message = "availability_type が REGIONAL の PostgreSQL では、point_in_time_recovery を有効にする必要があります。"
    }
  }
}

resource "google_sql_database" "app" {
  name     = var.db_name
  instance = google_sql_database_instance.this.name
}

# パスワードは Terraform で生成し、Secret Manager に格納する（人もコードも値を知らずに済む）。
# 注意: 値は Terraform の state に残る（ADR 0005）。state バケットのアクセス制御と暗号化で保護する。
resource "random_password" "db" {
  length  = 32
  special = false
}

resource "google_sql_user" "app" {
  name     = var.db_user
  instance = google_sql_database_instance.this.name
  password = random_password.db.result
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.name}-db-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}
