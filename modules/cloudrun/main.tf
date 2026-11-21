# 専用のサービスアカウントで動かす（既定の SA は、組織ポリシーで自動付与が無効なため使わない）。
resource "google_service_account" "run" {
  account_id   = "${var.name}-run"
  display_name = "Cloud Run runtime (${var.name})"
}

# 参照するシークレット1件ごとに、読み取り権限だけを付ける（最小権限）。
resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = var.secrets

  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run.email}"
}

resource "google_cloud_run_v2_service" "this" {
  name                = var.name
  location            = var.region
  ingress             = var.ingress
  deletion_protection = var.deletion_protection

  template {
    service_account = google_service_account.run.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    # Direct VPC egress: Cloud SQL の private IP へ VPC 経由で到達する。外向きは private 範囲のみ VPC を通す。
    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"

      network_interfaces {
        network    = var.network
        subnetwork = var.subnetwork
      }
    }

    containers {
      image = var.container_image

      ports {
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle = true
      }

      dynamic "env" {
        for_each = var.environment

        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secrets

        content {
          name = env.key

          value_source {
            secret_key_ref {
              secret  = env.value.secret_id
              version = env.value.version
            }
          }
        }
      }

      # Direct VPC egress は起動直後の接続に時間がかかることがあるため、余裕を持たせる。
      startup_probe {
        initial_delay_seconds = 0
        timeout_seconds       = 3
        period_seconds        = 5
        failure_threshold     = 24

        http_get {
          path = var.health_check_path
          port = var.container_port
        }
      }
    }
  }

  depends_on = [google_secret_manager_secret_iam_member.accessor]
}

# 未認証の公開（allUsers に起動権限）。組織ポリシーが許可している場合のみ有効にする。
resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.allow_unauthenticated ? 1 : 0

  name     = google_cloud_run_v2_service.this.name
  location = google_cloud_run_v2_service.this.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
