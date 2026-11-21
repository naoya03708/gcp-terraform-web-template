# dev: コスト優先の小規模構成
subnet_cidr = "10.0.0.0/24"
enable_nat  = false

db_tier                   = "db-f1-micro"
db_disk_size_gb           = 10
db_availability_type      = "ZONAL"
db_point_in_time_recovery = false
db_backup_retention_days  = 3

deletion_protection = false

run_cpu           = "1"
run_memory        = "512Mi"
run_min_instances = 0
run_max_instances = 2

# 仮の SLO（サンプルアプリ向け。実サービスでは合意した値に置き換える）
slo_availability_target  = 0.995
slo_latency_target       = 0.95
slo_latency_threshold_ms = 500
