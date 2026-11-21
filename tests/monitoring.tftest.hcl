mock_provider "google" {}

variables {
  name                     = "test"
  project_id               = "p"
  service_name             = "test-svc"
  db_instance_name         = "test-db"
  slo_availability_target  = 0.995
  slo_latency_target       = 0.95
  slo_latency_threshold_ms = 500
}

run "no_notification_without_email" {
  command = plan

  module {
    source = "./modules/monitoring"
  }

  assert {
    condition     = length(google_monitoring_notification_channel.page) == 0 && length(google_monitoring_notification_channel.ticket) == 0
    error_message = "alarm_email が未設定なら、通知チャネルを作らないこと"
  }
}

run "two_channels_with_email" {
  command = plan

  module {
    source = "./modules/monitoring"
  }

  variables {
    alarm_email = "oncall@example.com"
  }

  assert {
    condition     = length(google_monitoring_notification_channel.page) == 1 && length(google_monitoring_notification_channel.ticket) == 1
    error_message = "緊急用とチケット用の 2 系統の通知チャネルを作ること"
  }
}

run "slo_definitions" {
  command = plan

  module {
    source = "./modules/monitoring"
  }

  assert {
    condition     = google_monitoring_slo.availability.goal == 0.995 && google_monitoring_slo.availability.rolling_period_days == 30
    error_message = "可用性 SLO が 99.5%（30日）であること"
  }

  assert {
    condition     = strcontains(google_monitoring_slo.availability.request_based_sli[0].good_total_ratio[0].bad_service_filter, "5xx")
    error_message = "可用性は 5xx を悪いリクエストとして数えること"
  }

  assert {
    condition     = google_monitoring_slo.latency.goal == 0.95 && google_monitoring_slo.latency.request_based_sli[0].distribution_cut[0].range[0].max == 500
    error_message = "レイテンシ SLO が「95% が 500ms 以内」であること"
  }

  assert {
    condition     = strcontains(google_monitoring_slo.availability.request_based_sli[0].good_total_ratio[0].total_service_filter, "test-svc")
    error_message = "SLI が対象の Cloud Run サービスに絞られていること"
  }
}

run "burn_rate_policies" {
  command = plan

  module {
    source = "./modules/monitoring"
  }

  assert {
    condition     = google_monitoring_alert_policy.availability_fast_burn.combiner == "AND" && length(google_monitoring_alert_policy.availability_fast_burn.conditions) == 2
    error_message = "緊急アラートは、長窓と短窓の 2 条件の AND であること"
  }

  assert {
    condition     = google_monitoring_alert_policy.availability_fast_burn.conditions[0].condition_threshold[0].threshold_value == 14.4 && google_monitoring_alert_policy.availability_slow_burn.conditions[0].condition_threshold[0].threshold_value == 6
    error_message = "バーンレートの閾値が、緊急 14.4・チケット 6 であること"
  }

  # フィルタ（select_slo_burn_rate）は SLO の name（apply 後に確定）を含むため、plan のテストでは検証できない。実機で確認する。

  assert {
    condition     = google_monitoring_alert_policy.db_disk.conditions[0].condition_threshold[0].threshold_value == 0.85
    error_message = "DB のディスク使用率の既定の閾値が 0.85 であること"
  }
}

run "rejects_target_above_max" {
  command = plan

  module {
    source = "./modules/monitoring"
  }

  variables {
    slo_availability_target = 0.9999
  }

  expect_failures = [var.slo_availability_target]
}

run "rejects_rolling_period_above_30" {
  command = plan

  module {
    source = "./modules/monitoring"
  }

  variables {
    slo_rolling_period_days = 60
  }

  expect_failures = [var.slo_rolling_period_days]
}
