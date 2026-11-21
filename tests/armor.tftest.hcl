mock_provider "google" {}

variables {
  name         = "test"
  region       = "asia-northeast1"
  service_name = "test-svc"
  domain_name  = "app.example.com"
}

run "armor_enabled_by_default" {
  command = plan

  module {
    source = "./modules/armor"
  }

  assert {
    condition     = length(google_compute_security_policy.this) == 1
    error_message = "既定で Cloud Armor のポリシーを作ること"
  }

  assert {
    condition     = toset([for r in google_compute_security_policy.this[0].rule : r.priority]) == toset([1000, 1100, 2147483647])
    error_message = "SQLi / XSS の WAF ルールと、既定の許可ルールを持つこと"
  }

  assert {
    condition     = alltrue([for r in google_compute_security_policy.this[0].rule : r.action == "deny(403)" if r.priority < 2000000000]) && length([for r in google_compute_security_policy.this[0].rule : r if r.priority < 2000000000]) == 2
    error_message = "WAF ルール（SQLi / XSS）は、一致したリクエストを 403 で拒否すること"
  }
}

run "armor_disabled" {
  command = plan

  module {
    source = "./modules/armor"
  }

  variables {
    enable_armor = false
  }

  assert {
    condition     = length(google_compute_security_policy.this) == 0 && google_compute_backend_service.this.security_policy == null
    error_message = "enable_armor = false なら、ポリシーを作らず、バックエンドにもアタッチしないこと"
  }
}

run "https_with_redirect_and_tls12" {
  command = plan

  module {
    source = "./modules/armor"
  }

  assert {
    condition     = google_compute_global_forwarding_rule.https.port_range == "443" && google_compute_global_forwarding_rule.http.port_range == "80"
    error_message = "443（HTTPS）と、80（リダイレクト用）だけを公開すること"
  }

  assert {
    condition     = google_compute_url_map.redirect.default_url_redirect[0].https_redirect == true
    error_message = "HTTP は HTTPS へリダイレクトすること"
  }

  assert {
    condition     = google_compute_ssl_policy.this.min_tls_version == "TLS_1_2"
    error_message = "TLS 1.2 未満を受け付けないこと"
  }

  assert {
    condition     = google_compute_region_network_endpoint_group.run.network_endpoint_type == "SERVERLESS" && google_compute_region_network_endpoint_group.run.cloud_run[0].service == "test-svc"
    error_message = "Cloud Run をバックエンドとする serverless NEG であること"
  }
}

run "rejects_invalid_domain" {
  command = plan

  module {
    source = "./modules/armor"
  }

  variables {
    domain_name = "Not A Domain"
  }

  expect_failures = [var.domain_name]
}
