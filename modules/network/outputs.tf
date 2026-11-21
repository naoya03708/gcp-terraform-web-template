output "network_id" {
  description = "VPC ネットワークの ID"
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "VPC ネットワーク名"
  value       = google_compute_network.this.name
}

output "subnet_id" {
  description = "サブネットの ID"
  value       = google_compute_subnetwork.this.id
}

output "subnet_name" {
  description = "サブネット名"
  value       = google_compute_subnetwork.this.name
}

output "psa_connection_id" {
  description = "private services access の接続 ID（Cloud SQL はこれに依存させる）"
  value       = google_service_networking_connection.psa.id
}
