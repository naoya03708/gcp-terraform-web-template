output "service_name" {
  description = "Cloud Run サービス名"
  value       = google_cloud_run_v2_service.this.name
}

output "url" {
  description = "Cloud Run の URL（*.run.app。Google 管理の証明書で HTTPS）"
  value       = google_cloud_run_v2_service.this.uri
}

output "service_account_email" {
  description = "実行用サービスアカウントのメールアドレス"
  value       = google_service_account.run.email
}
