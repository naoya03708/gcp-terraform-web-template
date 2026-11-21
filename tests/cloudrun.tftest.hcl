mock_provider "google" {}

variables {
  name                = "test"
  region              = "asia-northeast1"
  container_image     = "us-docker.pkg.dev/cloudrun/container/hello"
  container_port      = 8080
  cpu                 = "1"
  memory              = "512Mi"
  network             = "test-vpc"
  subnetwork          = "test-subnet"
  deletion_protection = false
}

run "dev_scale_to_zero" {
  command = plan

  module {
    source = "./modules/cloudrun"
  }

  variables {
    min_instances = 0
    max_instances = 2
  }

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].scaling[0].min_instance_count == 0 && google_cloud_run_v2_service.this.template[0].scaling[0].max_instance_count == 2
    error_message = "dev は最小 0・最大 2 インスタンスであること"
  }

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].vpc_access[0].egress == "PRIVATE_RANGES_ONLY"
    error_message = "Direct VPC egress で、private 範囲のみ VPC を通すこと"
  }

  assert {
    condition     = length(google_cloud_run_v2_service_iam_member.public) == 1
    error_message = "既定では未認証のアクセスを許可すること"
  }

  assert {
    condition     = google_cloud_run_v2_service.this.deletion_protection == false
    error_message = "dev は削除保護なしであること（destroy で消せる）"
  }

  assert {
    condition     = google_service_account.run.account_id == "test-run"
    error_message = "専用のサービスアカウントで動かすこと"
  }
}

run "private_when_unauthenticated_disabled" {
  command = plan

  module {
    source = "./modules/cloudrun"
  }

  variables {
    min_instances         = 1
    max_instances         = 4
    allow_unauthenticated = false
    deletion_protection   = true
  }

  assert {
    condition     = length(google_cloud_run_v2_service_iam_member.public) == 0
    error_message = "allow_unauthenticated = false では allUsers に起動権限を付けないこと"
  }

  assert {
    condition     = google_cloud_run_v2_service.this.deletion_protection == true
    error_message = "prod は削除保護ありであること"
  }
}

run "secrets_injected_by_reference" {
  command = plan

  module {
    source = "./modules/cloudrun"
  }

  variables {
    min_instances = 0
    max_instances = 2
    environment = {
      DB_HOST = "10.0.0.5"
    }
    secrets = {
      DB_PASSWORD = {
        secret_id = "test-db-password"
        version   = "3"
      }
    }
  }

  assert {
    condition     = length(google_secret_manager_secret_iam_member.accessor) == 1 && google_secret_manager_secret_iam_member.accessor["DB_PASSWORD"].role == "roles/secretmanager.secretAccessor"
    error_message = "参照するシークレット1件ごとに、読み取り権限だけを付けること"
  }

  assert {
    condition     = length([for e in google_cloud_run_v2_service.this.template[0].containers[0].env : e if e.name == "DB_PASSWORD" && length(e.value_source) > 0 ? e.value_source[0].secret_key_ref[0].version == "3" : false]) == 1
    error_message = "パスワードは平文ではなく、固定バージョンのシークレット参照で渡すこと"
  }
}

run "restricts_ingress_to_load_balancer" {
  command = plan

  module {
    source = "./modules/cloudrun"
  }

  variables {
    min_instances = 0
    max_instances = 2
    ingress       = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  }

  assert {
    condition     = google_cloud_run_v2_service.this.ingress == "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
    error_message = "ingress を LB 経由のみに絞れること"
  }
}

run "rejects_invalid_ingress" {
  command = plan

  module {
    source = "./modules/cloudrun"
  }

  variables {
    min_instances = 0
    max_instances = 2
    ingress       = "ANYTHING"
  }

  expect_failures = [var.ingress]
}

run "rejects_max_below_min" {
  command = plan

  module {
    source = "./modules/cloudrun"
  }

  variables {
    min_instances = 3
    max_instances = 2
  }

  expect_failures = [var.max_instances]
}
