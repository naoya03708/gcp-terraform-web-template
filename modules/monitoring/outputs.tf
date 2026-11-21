output "availability_slo_name" {
  description = "可用性 SLO のリソース名"
  value       = google_monitoring_slo.availability.name
}

output "latency_slo_name" {
  description = "レイテンシ SLO のリソース名"
  value       = google_monitoring_slo.latency.name
}

output "dashboard_id" {
  description = "ダッシュボードの ID"
  value       = google_monitoring_dashboard.this.id
}

output "notifications_enabled" {
  description = "通知チャネルを作成したか（alarm_email を渡した場合 true）"
  value       = local.notify
}
