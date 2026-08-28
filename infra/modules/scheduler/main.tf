variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "location" {
  type        = string
  description = "Region for Scheduler job (e.g. asia-northeast1)"
}

variable "name" {
  type        = string
  description = "Scheduler job name"
}

variable "schedule" {
  type        = string
  description = "Cron schedule expression"
}

variable "time_zone" {
  type        = string
  description = "Time zone for the schedule (e.g. Asia/Tokyo)"
}

variable "run_job_location" {
  type        = string
  description = "Region of the Cloud Run Job to trigger"
}

variable "run_job_name" {
  type        = string
  description = "Name of the Cloud Run Job to trigger"
}

variable "service_account_email" {
  type        = string
  description = "Service account email used by Cloud Scheduler to call Cloud Run Job"
}

resource "google_cloud_scheduler_job" "this" {
  name        = var.name
  project     = var.project_id
  region      = var.location
  description = "Triggers Cloud Run Job ${var.run_job_name} on schedule"

  schedule  = var.schedule
  time_zone = var.time_zone

  http_target {
    http_method = "POST"
    uri         = "https://${var.run_job_location}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${var.run_job_name}:run"

    oauth_token {
      service_account_email = var.service_account_email
      # scope 省略時は cloud-platform が使われ、Cloud Run への呼び出しに十分です
    }
  }
}

output "name" {
  description = "Scheduler job name"
  value       = google_cloud_scheduler_job.this.name
}
