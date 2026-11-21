output "instance_name" {
  description = "Cloud SQL インスタンス名"
  value       = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "Cloud SQL の接続名（project:region:instance）"
  value       = google_sql_database_instance.this.connection_name
}

output "private_ip_address" {
  description = "Cloud SQL の private IP アドレス"
  value       = google_sql_database_instance.this.private_ip_address
}

output "db_name" {
  description = "データベース名"
  value       = google_sql_database.app.name
}

output "db_user" {
  description = "アプリ用のデータベースユーザー名"
  value       = google_sql_user.app.name
}

output "password_secret_id" {
  description = "DB パスワードの Secret Manager のシークレット ID"
  value       = google_secret_manager_secret.db_password.secret_id
}

output "password_secret_version" {
  description = "DB パスワードのシークレットのバージョン番号（Cloud Run には固定のバージョンを参照させる）"
  value       = google_secret_manager_secret_version.db_password.version
}
