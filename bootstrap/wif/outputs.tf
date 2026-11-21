# プロジェクト番号を含むため sensitive にしている。値は GitHub Secrets に登録する:
#   terraform output -raw workload_identity_provider

output "workload_identity_provider" {
  description = "GitHub Secrets（GCP_WIF_PROVIDER）に登録する Workload Identity Provider のリソース名"
  value       = google_iam_workload_identity_pool_provider.github.name
  sensitive   = true
}

output "plan_service_account" {
  description = "GitHub Secrets（GCP_PLAN_SA）に登録する plan 用サービスアカウント"
  value       = google_service_account.plan.email
  sensitive   = true
}

output "apply_service_account" {
  description = "GitHub Secrets（GCP_APPLY_SA）に登録する apply 用サービスアカウント"
  value       = google_service_account.apply.email
  sensitive   = true
}
