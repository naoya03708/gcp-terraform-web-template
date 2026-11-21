# dev: コスト優先の小規模構成
subnet_cidr = "10.0.0.0/24"
enable_nat  = false

db_tier                   = "db-f1-micro"
db_disk_size_gb           = 10
db_availability_type      = "ZONAL"
db_point_in_time_recovery = false
db_backup_retention_days  = 3

deletion_protection = false
