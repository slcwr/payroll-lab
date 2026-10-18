resource "google_sql_database_instance" "main" {
  name             = "${local.name}-pg"
  database_version = "POSTGRES_16"
  region           = var.region

  settings {
    tier              = var.db_tier
    availability_type = var.env == "prod" ? "REGIONAL" : "ZONAL"

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }

    ip_configuration {
      # 接続は Cloud Run の Cloud SQL 連携（IAM 認可つきのコネクタ）のみ。許可ネットワークは設定しない
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
    }

    insights_config {
      query_insights_enabled = true # 遅いクエリの調査用
    }

    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"
    }
  }

  deletion_protection = var.env == "prod"
  depends_on          = [google_project_service.apis]
}

resource "google_sql_database" "app" {
  name     = "payroll_lab"
  instance = google_sql_database_instance.main.name
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "google_sql_user" "app" {
  name     = "payroll_lab"
  instance = google_sql_database_instance.main.name
  password = random_password.db.result
}

# Cloud Run では /cloudsql/<接続名> の Unix ソケットで接続する
resource "google_secret_manager_secret" "database_url" {
  secret_id = "${local.name}-database-url"
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "database_url" {
  secret = google_secret_manager_secret.database_url.id
  secret_data = format(
    "postgres://%s:%s@/%s?host=/cloudsql/%s",
    google_sql_user.app.name, random_password.db.result, google_sql_database.app.name,
    google_sql_database_instance.main.connection_name
  )
}
