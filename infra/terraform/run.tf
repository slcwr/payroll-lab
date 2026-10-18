locals {
  rails_env = [
    { name = "RAILS_ENV", value = "production" },
    { name = "RAILS_LOG_LEVEL", value = "info" },
    { name = "LANG", value = "C.UTF-8" },
  ]
  rails_secrets = {
    DATABASE_URL    = google_secret_manager_secret.database_url.secret_id
    SECRET_KEY_BASE = google_secret_manager_secret.secret_key_base.secret_id
  }
}

# ---- API（GraphQL）----
resource "google_cloud_run_v2_service" "api" {
  name     = "${local.name}-api"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.api.email

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.main.connection_name]
      }
    }

    containers {
      image = var.api_image
      ports {
        container_port = 3000
      }

      dynamic "env" {
        for_each = concat(local.rails_env, [
          { name = "CORS_ORIGINS", value = var.web_origin },
          { name = "PAYROLL_DISPATCHER", value = "cloud_run_job" },
          { name = "PAYROLL_JOB_NAME", value = google_cloud_run_v2_job.payroll.name },
          { name = "PAYROLL_SHARD_COUNT", value = tostring(var.payroll_shard_count) },
          { name = "GOOGLE_CLOUD_PROJECT", value = var.project_id },
          { name = "CLOUD_RUN_REGION", value = var.region },
        ])
        content {
          name  = env.value.name
          value = env.value.value
        }
      }

      dynamic "env" {
        for_each = local.rails_secrets
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      startup_probe {
        http_get {
          path = "/up"
        }
        initial_delay_seconds = 5
        failure_threshold     = 30
        period_seconds        = 5
      }
    }
  }

  depends_on = [google_secret_manager_secret_iam_member.accessor, google_project_iam_member.cloudsql_client]
}

# ---- 給与計算バッチ（Cloud Run Jobs）----
# API が実行時に taskCount と引数（payroll:calculate[ID]）を上書きして起動する。
# 各タスクは CLOUD_RUN_TASK_INDEX で担当する従業員を分ける。
resource "google_cloud_run_v2_job" "payroll" {
  name     = "${local.name}-payroll"
  location = var.region

  template {
    task_count  = var.payroll_shard_count
    parallelism = var.payroll_shard_count

    template {
      service_account = google_service_account.job.email
      timeout         = "3600s"
      max_retries     = 1 # 計算は冪等なので、失敗したタスクは再実行してよい

      volumes {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [google_sql_database_instance.main.connection_name]
        }
      }

      containers {
        image = var.api_image
        args  = ["./bin/rails", "payroll:calculate[0]"]

        resources {
          limits = {
            cpu    = "2"
            memory = "2Gi"
          }
        }

        dynamic "env" {
          for_each = local.rails_env
          content {
            name  = env.value.name
            value = env.value.value
          }
        }

        dynamic "env" {
          for_each = local.rails_secrets
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value
                version = "latest"
              }
            }
          }
        }

        volume_mounts {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }
    }
  }

  depends_on = [google_secret_manager_secret_iam_member.accessor, google_project_iam_member.cloudsql_client]
}

# ---- フロントエンド ----
resource "google_cloud_run_v2_service" "web" {
  name     = "${local.name}-web"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.web.email
    containers {
      image = var.web_image
      ports {
        container_port = 3001
      }
    }
  }
}

# 学習用のため誰でもアクセスできるようにしている。
# 実運用では Identity-Aware Proxy やアプリの認証を必ず入れる。
resource "google_cloud_run_v2_service_iam_member" "public" {
  for_each = {
    api = google_cloud_run_v2_service.api.name
    web = google_cloud_run_v2_service.web.name
  }
  name     = each.value
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}
