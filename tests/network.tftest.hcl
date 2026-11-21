mock_provider "google" {}

run "defaults_without_nat" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    name   = "test"
    region = "asia-northeast1"
  }

  assert {
    condition     = google_compute_network.this.auto_create_subnetworks == false
    error_message = "既定のサブネットを自動作成しないこと（カスタムモードの VPC）"
  }

  assert {
    condition     = google_compute_subnetwork.this.private_ip_google_access == true
    error_message = "Google API へ private に到達できるよう、サブネットで Private Google Access が有効であること"
  }

  assert {
    condition     = google_compute_global_address.psa.purpose == "VPC_PEERING" && google_compute_global_address.psa.address_type == "INTERNAL"
    error_message = "Cloud SQL 用に、VPC ピアリング目的の内部アドレス範囲を予約すること"
  }

  assert {
    condition     = length(google_compute_router.this) == 0 && length(google_compute_router_nat.this) == 0
    error_message = "enable_nat が既定（false）の場合、Cloud NAT を作らないこと"
  }
}

run "nat_enabled" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    name       = "test"
    region     = "asia-northeast1"
    enable_nat = true
  }

  assert {
    condition     = length(google_compute_router.this) == 1 && length(google_compute_router_nat.this) == 1
    error_message = "enable_nat = true の場合、Cloud Router と Cloud NAT を1つずつ作ること"
  }
}

run "rejects_too_small_subnet" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    name        = "test"
    region      = "asia-northeast1"
    subnet_cidr = "10.0.0.0/28"
  }

  expect_failures = [var.subnet_cidr]
}

run "rejects_too_small_psa_range" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    name              = "test"
    region            = "asia-northeast1"
    psa_prefix_length = 28
  }

  expect_failures = [var.psa_prefix_length]
}
