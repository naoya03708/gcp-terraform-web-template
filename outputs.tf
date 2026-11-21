output "enabled_apis" {
  description = "有効化した API の一覧"
  value       = sort([for s in google_project_service.this : s.service])
}

output "name" {
  description = "リソース名のプレフィックス（<project>-<env>）"
  value       = local.name
}

output "network_name" {
  description = "VPC ネットワーク名"
  value       = module.network.network_name
}

output "db_instance_name" {
  description = "Cloud SQL インスタンス名"
  value       = module.cloudsql.instance_name
}

output "db_connection_name" {
  description = "Cloud SQL の接続名（project:region:instance）"
  value       = module.cloudsql.connection_name
}

output "db_password_secret_id" {
  description = "DB パスワードの Secret Manager のシークレット ID（値は出力しない）"
  value       = module.cloudsql.password_secret_id
}

output "app_url" {
  description = "アプリの URL（*.run.app。HTTPS）"
  value       = module.cloudrun.url
}

output "cloudrun_service_name" {
  description = "Cloud Run サービス名"
  value       = module.cloudrun.service_name
}

output "dashboard_id" {
  description = "SLO ダッシュボードの ID"
  value       = module.monitoring.dashboard_id
}
