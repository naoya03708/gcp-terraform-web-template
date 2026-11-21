output "lb_ip_address" {
  description = "LB のグローバル IP。ドメインの A レコードをここに向ける（向けるまで、証明書は発行されない）"
  value       = google_compute_global_address.lb.address
}

output "https_url" {
  description = "LB 経由の URL"
  value       = "https://${var.domain_name}"
}

output "security_policy_name" {
  description = "Cloud Armor のポリシー名（enable_armor が false なら null）"
  value       = var.enable_armor ? google_compute_security_policy.this[0].name : null
}
