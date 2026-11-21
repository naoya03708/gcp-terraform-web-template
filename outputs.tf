output "enabled_apis" {
  description = "有効化した API の一覧"
  value       = sort([for s in google_project_service.this : s.service])
}

output "name" {
  description = "リソース名のプレフィックス（<project>-<env>）"
  value       = local.name
}
