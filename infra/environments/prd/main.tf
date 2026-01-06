terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Artifact Registry リポジトリ（Docker 用）
resource "google_artifact_registry_repository" "zutool_notifier" {
  project       = var.project_id
  location      = var.region
  repository_id = "zutool-notifier"
  format        = "DOCKER"
}

# Cloud Run Job 実行用サービスアカウント
resource "google_service_account" "cloud_run_job" {
  account_id   = "zutool-notifier-job"
  display_name = "Zutool Notifier Cloud Run Job SA"
}

# Cloud Scheduler から Cloud Run Job を呼び出すためのサービスアカウント
resource "google_service_account" "scheduler" {
  account_id   = "zutool-notifier-scheduler"
  display_name = "Zutool Notifier Scheduler SA"
}

# Cloud Run Job 用サービスアカウントにプロジェクトレベルで必要最低限のロールを付与
resource "google_project_iam_member" "cloud_run_job_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run_job.email}"
}

resource "google_project_iam_member" "cloud_run_job_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_job.email}"
}

# Scheduler 用サービスアカウントに Cloud Run Invoker 権限を付与（ジョブの実行権限として利用）
resource "google_project_iam_member" "scheduler_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.scheduler.email}"
}

module "slack_secret" {
  source    = "../../modules/secret_manager"
  project_id = var.project_id
  secret_id  = "SLACK_WEBHOOK_URL"
  labels = {
    app = "zutool-notifier"
    env = "prd"
  }
}

module "line_secret" {
  count      = var.enable_line_notification ? 1 : 0
  source     = "../../modules/secret_manager"
  project_id = var.project_id
  secret_id  = "LINE_CHANNEL_ACCESS_TOKEN"
  labels = {
    app = "zutool-notifier"
    env = "prd"
  }
}

module "cloud_run_job" {
  source = "../../modules/cloud_run_job"

  project_id            = var.project_id
  location              = var.region
  name                  = var.job_name
  image                 = "asia-northeast1-docker.pkg.dev/${var.project_id}/zutool-notifier/zutool-notifier:latest"
  service_account_email = google_service_account.cloud_run_job.email

  env = {
    ZUTOOL_PLACE_ID          = var.zutool_place_id
    PRESSURE_LEVEL_THRESHOLD = tostring(var.pressure_level_threshold)
    ALWAYS_NOTIFY            = var.always_notify ? "true" : "false"
    LINE_USER_ID             = var.line_user_id
  }

  secrets = merge(
    {
      SLACK_WEBHOOK_URL = module.slack_secret.name
    },
    var.enable_line_notification ? {
      LINE_CHANNEL_ACCESS_TOKEN = module.line_secret[0].name
    } : {}
  )
}

module "scheduler" {
  source = "../../modules/scheduler"

  project_id           = var.project_id
  location             = var.scheduler_region
  name                 = var.scheduler_name
  schedule             = var.scheduler_cron
  time_zone            = var.scheduler_time_zone
  run_job_location     = var.region
  run_job_name         = module.cloud_run_job.name
  service_account_email = google_service_account.scheduler.email
}
