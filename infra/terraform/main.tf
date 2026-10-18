locals {
  name = "payroll-lab-${var.env}"
}

resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "images" {
  location      = var.region
  repository_id = "payroll-lab"
  format        = "DOCKER"
  depends_on    = [google_project_service.apis]
}

# ---- サービスアカウント（役割ごとに分けて最小権限にする）----

resource "google_service_account" "api" {
  account_id   = "${local.name}-api"
  display_name = "payroll-lab API (Cloud Run service)"
}

resource "google_service_account" "job" {
  account_id   = "${local.name}-job"
  display_name = "payroll-lab 給与計算バッチ (Cloud Run job)"
}

resource "google_service_account" "web" {
  account_id   = "${local.name}-web"
  display_name = "payroll-lab Web (Cloud Run service)"
}

resource "google_project_iam_member" "cloudsql_client" {
  for_each = {
    api = google_service_account.api.email
    job = google_service_account.job.email
  }
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${each.value}"
}

# API がジョブを引数つきで起動できるようにする（ジョブ単位で付与）
resource "google_cloud_run_v2_job_iam_member" "api_runs_job" {
  name     = google_cloud_run_v2_job.payroll.name
  location = var.region
  role     = "roles/run.developer"
  member   = "serviceAccount:${google_service_account.api.email}"
}

# ジョブを起動するには、ジョブの実行サービスアカウントとして振る舞う権限も要る
resource "google_service_account_iam_member" "api_act_as_job" {
  service_account_id = google_service_account.job.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.api.email}"
}

# ---- シークレット ----

resource "random_password" "secret_key_base" {
  length  = 64
  special = false
}

resource "google_secret_manager_secret" "secret_key_base" {
  secret_id = "${local.name}-secret-key-base"
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "secret_key_base" {
  secret      = google_secret_manager_secret.secret_key_base.id
  secret_data = random_password.secret_key_base.result
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = {
    "api-url" = { secret = google_secret_manager_secret.database_url.id, sa = google_service_account.api.email }
    "job-url" = { secret = google_secret_manager_secret.database_url.id, sa = google_service_account.job.email }
    "api-skb" = { secret = google_secret_manager_secret.secret_key_base.id, sa = google_service_account.api.email }
    "job-skb" = { secret = google_secret_manager_secret.secret_key_base.id, sa = google_service_account.job.email }
  }
  secret_id = each.value.secret
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.sa}"
}
