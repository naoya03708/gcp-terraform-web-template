locals {
  # Cloud Run のメトリクスの共通の絞り込み条件
  run_resource = "resource.type=\"cloud_run_revision\" resource.labels.service_name=\"${var.service_name}\""

  total_filter   = "metric.type=\"run.googleapis.com/request_count\" ${local.run_resource}"
  bad_filter     = "${local.total_filter} metric.labels.response_code_class=\"5xx\""
  latency_filter = "metric.type=\"run.googleapis.com/request_latencies\" ${local.run_resource}"

  # alarm_email が未設定なら通知チャネルを作らない。
  # 変数の値は plan に出さない運用のため、有無の判定だけを非 sensitive にして count に使う。
  notify = nonsensitive(var.alarm_email != null)

  page_channels   = [for c in google_monitoring_notification_channel.page : c.id]
  ticket_channels = [for c in google_monitoring_notification_channel.ticket : c.id]
}

# --- 通知チャネル（緊急 / チケットの 2 系統。検証では同じ宛先） ---
resource "google_monitoring_notification_channel" "page" {
  count = local.notify ? 1 : 0

  display_name = "${var.name} page"
  type         = "email"

  labels = {
    email_address = var.alarm_email
  }
}

resource "google_monitoring_notification_channel" "ticket" {
  count = local.notify ? 1 : 0

  display_name = "${var.name} ticket"
  type         = "email"

  labels = {
    email_address = var.alarm_email
  }
}

# --- SLO ---
# Cloud Run は自動検出のサービスではないため、カスタムサービスを作って SLO を紐づける。
resource "google_monitoring_custom_service" "this" {
  service_id   = "${var.name}-service"
  display_name = "${var.name} (Cloud Run)"
}

# 可用性: 5xx 以外を良いリクエストとする（4xx はクライアント起因のため良とみなす。AWS 版と同じ）
resource "google_monitoring_slo" "availability" {
  service      = google_monitoring_custom_service.this.service_id
  slo_id       = "${var.name}-availability"
  display_name = "Availability ${var.slo_availability_target * 100}% (${var.slo_rolling_period_days}d)"

  goal                = var.slo_availability_target
  rolling_period_days = var.slo_rolling_period_days

  request_based_sli {
    good_total_ratio {
      bad_service_filter   = local.bad_filter
      total_service_filter = local.total_filter
    }
  }
}

# レイテンシ: 「閾値以内で応答したリクエストの割合」。AWS 版の p95 閾値とは SLI の定義が異なる（docs/slo.md 参照）。
resource "google_monitoring_slo" "latency" {
  service      = google_monitoring_custom_service.this.service_id
  slo_id       = "${var.name}-latency"
  display_name = "Latency ${var.slo_latency_target * 100}% under ${var.slo_latency_threshold_ms}ms (${var.slo_rolling_period_days}d)"

  goal                = var.slo_latency_target
  rolling_period_days = var.slo_rolling_period_days

  request_based_sli {
    distribution_cut {
      distribution_filter = local.latency_filter

      range {
        max = var.slo_latency_threshold_ms
      }
    }
  }
}

# --- バーンレートのアラート（multi-window multi-burn-rate） ---
# 緊急: 14.4 倍（1h ∧ 5m）= 30 日の予算を約 2 日で使い切る速さ
# チケット: 6 倍（6h ∧ 30m）= 同じく約 5 日
# 長窓と短窓の AND（combiner = "AND"）は公式の例に無く、実機での動作は未確認（README 参照）。
resource "google_monitoring_alert_policy" "availability_fast_burn" {
  display_name = "${var.name} availability fast burn (page)"
  combiner     = "AND"
  severity     = "CRITICAL"

  conditions {
    display_name = "[page] burn rate > 14.4 (1h)"

    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.availability.name}\", \"1h\")"
      comparison      = "COMPARISON_GT"
      threshold_value = 14.4
      duration        = "0s"
    }
  }

  conditions {
    display_name = "[page] burn rate > 14.4 (5m)"

    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.availability.name}\", \"5m\")"
      comparison      = "COMPARISON_GT"
      threshold_value = 14.4
      duration        = "0s"
    }
  }

  notification_channels = local.page_channels

  documentation {
    mime_type = "text/markdown"
    content   = "可用性のエラーバジェットを急速に消費しています。一次対応は docs/slo.md の「availability fast burn」を参照。"
  }
}

resource "google_monitoring_alert_policy" "availability_slow_burn" {
  display_name = "${var.name} availability slow burn (ticket)"
  combiner     = "AND"
  severity     = "WARNING"

  conditions {
    display_name = "[ticket] burn rate > 6 (6h)"

    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.availability.name}\", \"6h\")"
      comparison      = "COMPARISON_GT"
      threshold_value = 6
      duration        = "0s"
    }
  }

  conditions {
    display_name = "[ticket] burn rate > 6 (30m)"

    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.availability.name}\", \"30m\")"
      comparison      = "COMPARISON_GT"
      threshold_value = 6
      duration        = "0s"
    }
  }

  notification_channels = local.ticket_channels

  documentation {
    mime_type = "text/markdown"
    content   = "可用性のエラーバジェットをゆるやかに消費しています。一次対応は docs/slo.md の「availability slow burn」を参照。"
  }
}

resource "google_monitoring_alert_policy" "latency_fast_burn" {
  display_name = "${var.name} latency fast burn (page)"
  combiner     = "AND"
  severity     = "CRITICAL"

  conditions {
    display_name = "[page] burn rate > 14.4 (1h)"

    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.latency.name}\", \"1h\")"
      comparison      = "COMPARISON_GT"
      threshold_value = 14.4
      duration        = "0s"
    }
  }

  conditions {
    display_name = "[page] burn rate > 14.4 (5m)"

    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.latency.name}\", \"5m\")"
      comparison      = "COMPARISON_GT"
      threshold_value = 14.4
      duration        = "0s"
    }
  }

  notification_channels = local.page_channels

  documentation {
    mime_type = "text/markdown"
    content   = "レイテンシのエラーバジェットを急速に消費しています。一次対応は docs/slo.md の「latency fast burn」を参照。"
  }
}

resource "google_monitoring_alert_policy" "latency_slow_burn" {
  display_name = "${var.name} latency slow burn (ticket)"
  combiner     = "AND"
  severity     = "WARNING"

  conditions {
    display_name = "[ticket] burn rate > 6 (6h)"

    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.latency.name}\", \"6h\")"
      comparison      = "COMPARISON_GT"
      threshold_value = 6
      duration        = "0s"
    }
  }

  conditions {
    display_name = "[ticket] burn rate > 6 (30m)"

    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.latency.name}\", \"30m\")"
      comparison      = "COMPARISON_GT"
      threshold_value = 6
      duration        = "0s"
    }
  }

  notification_channels = local.ticket_channels

  documentation {
    mime_type = "text/markdown"
    content   = "レイテンシのエラーバジェットをゆるやかに消費しています。一次対応は docs/slo.md の「latency slow burn」を参照。"
  }
}

# --- 唯一の原因系アラーム: Cloud SQL のディスク逼迫（自動拡張が追いつかない前に気づく） ---
resource "google_monitoring_alert_policy" "db_disk" {
  display_name = "${var.name} Cloud SQL disk utilization (ticket)"
  combiner     = "OR"
  severity     = "WARNING"

  conditions {
    display_name = "[ticket] disk utilization > ${var.db_disk_utilization_threshold * 100}%"

    condition_threshold {
      filter          = "metric.type=\"cloudsql.googleapis.com/database/disk/utilization\" resource.type=\"cloudsql_database\" resource.labels.database_id=\"${var.project_id}:${var.db_instance_name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.db_disk_utilization_threshold
      duration        = "300s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.ticket_channels

  documentation {
    mime_type = "text/markdown"
    content   = "Cloud SQL のディスク使用率が高くなっています。一次対応は docs/slo.md の「DB disk」を参照。"
  }
}

# --- ダッシュボード（上段: SLO、下段: 原因調査用） ---
# タイルの定義は単体テストで検証できない（AWS 版で実機でしか見つからない不具合があった）。実機で確認する。
resource "google_monitoring_dashboard" "this" {
  dashboard_json = jsonencode({
    displayName = "${var.name} SLO"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos   = 0
          yPos   = 0
          width  = 6
          height = 3
          widget = {
            title = "Availability SLO compliance (${var.slo_rolling_period_days}d)"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "select_slo_compliance(\"${google_monitoring_slo.availability.name}\")"
                }
              }
            }
          }
        },
        {
          xPos   = 6
          yPos   = 0
          width  = 6
          height = 3
          widget = {
            title = "Latency SLO compliance (${var.slo_rolling_period_days}d)"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "select_slo_compliance(\"${google_monitoring_slo.latency.name}\")"
                }
              }
            }
          }
        },
        {
          xPos   = 0
          yPos   = 3
          width  = 6
          height = 4
          widget = {
            title = "Availability error budget remaining"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "select_slo_budget_fraction(\"${google_monitoring_slo.availability.name}\")"
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 3
          width  = 6
          height = 4
          widget = {
            title = "Latency error budget remaining"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "select_slo_budget_fraction(\"${google_monitoring_slo.latency.name}\")"
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 0
          yPos   = 7
          width  = 6
          height = 4
          widget = {
            title = "Requests by response class"
            xyChart = {
              dataSets = [{
                plotType = "STACKED_BAR"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = local.total_filter
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.label.response_code_class"]
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 7
          width  = 6
          height = 4
          widget = {
            title = "Request latency p95 (ms)"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = local.latency_filter
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_PERCENTILE_95"
                      crossSeriesReducer = "REDUCE_MAX"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 0
          yPos   = 11
          width  = 6
          height = 4
          widget = {
            title = "Cloud Run instance count"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/container/instance_count\" ${local.run_resource}"
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MAX"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 11
          width  = 6
          height = 4
          widget = {
            title = "Cloud SQL disk utilization"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"cloudsql.googleapis.com/database/disk/utilization\" resource.type=\"cloudsql_database\" resource.labels.database_id=\"${var.project_id}:${var.db_instance_name}\""
                  }
                }
              }]
            }
          }
        },
      ]
    }
  })
}
