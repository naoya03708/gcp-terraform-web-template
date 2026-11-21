# 外部 Application LB（Cloud Run をバックエンドにする serverless NEG）。
# HTTPS のみ提供し、HTTP は HTTPS へリダイレクトする。ドメインが無い環境では有効化しない（root で検証）。

resource "google_compute_global_address" "lb" {
  name = "${var.name}-lb-ip"
}

resource "google_compute_region_network_endpoint_group" "run" {
  name                  = "${var.name}-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.service_name
  }
}

# --- Cloud Armor ---
resource "google_compute_security_policy" "this" {
  count = var.enable_armor ? 1 : 0

  name = "${var.name}-armor"

  # 事前定義の WAF ルール（OWASP の SQL インジェクション / XSS）。感度は標準（stable）。
  rule {
    action   = "deny(403)"
    priority = 1000

    match {
      expr {
        expression = "evaluatePreconfiguredWaf('sqli-v33-stable')"
      }
    }

    description = "Block SQL injection"
  }

  rule {
    action   = "deny(403)"
    priority = 1100

    match {
      expr {
        expression = "evaluatePreconfiguredWaf('xss-v33-stable')"
      }
    }

    description = "Block cross-site scripting"
  }

  # 既定は許可（最後に評価される規定のルール）
  rule {
    action   = "allow"
    priority = 2147483647

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = ["*"]
      }
    }

    description = "Default allow"
  }
}

resource "google_compute_backend_service" "this" {
  name                  = "${var.name}-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  security_policy       = var.enable_armor ? google_compute_security_policy.this[0].id : null

  backend {
    group = google_compute_region_network_endpoint_group.run.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "https" {
  name            = "${var.name}-https"
  default_service = google_compute_backend_service.this.id
}

# --- HTTPS ---
# 証明書は、ドメインが変わると作り直しになる。同じ名前のまま作り直せないため、ドメインに紐づく接尾辞を付ける。
resource "random_id" "cert" {
  byte_length = 3

  keepers = {
    domain = var.domain_name
  }
}

resource "google_compute_managed_ssl_certificate" "this" {
  name = "${var.name}-cert-${random_id.cert.hex}"

  managed {
    domains = [var.domain_name]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# TLS 1.2 未満は受け付けない
resource "google_compute_ssl_policy" "this" {
  name            = "${var.name}-ssl"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

resource "google_compute_target_https_proxy" "this" {
  name             = "${var.name}-https-proxy"
  url_map          = google_compute_url_map.https.id
  ssl_certificates = [google_compute_managed_ssl_certificate.this.id]
  ssl_policy       = google_compute_ssl_policy.this.id
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${var.name}-https"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb.id
  port_range            = "443"
  target                = google_compute_target_https_proxy.this.id
}

# --- HTTP → HTTPS リダイレクト ---
resource "google_compute_url_map" "redirect" {
  name = "${var.name}-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "redirect" {
  name    = "${var.name}-http-proxy"
  url_map = google_compute_url_map.redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.name}-http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb.id
  port_range            = "80"
  target                = google_compute_target_http_proxy.redirect.id
}
