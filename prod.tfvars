# prod: 可用性・保護を優先した構成
subnet_cidr = "10.1.0.0/24"
enable_nat  = false

db_tier                   = "db-custom-1-3840"
db_disk_size_gb           = 20
db_availability_type      = "REGIONAL"
db_point_in_time_recovery = true
db_backup_retention_days  = 7

deletion_protection = true
