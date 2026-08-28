variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "location" {
  type        = string
  description = "Region for Cloud Run Job"
}

variable "name" {
  type        = string
  description = "Cloud Run Job name"
}

variable "image" {
  type        = string
  description = "Container image for the job"
}

variable "service_account_email" {
  type        = string
  description = "Service account email used to run the job"
}

variable "env" {
  type        = map(string)
  description = "Plain environment variables for the container"
  default     = {}
}

variable "slack_secret_name" {
  type        = string
  description = "Secret Manager secret resource name for SLACK_WEBHOOK_URL"
}

resource "google_cloud_run_v2_job" "this" {
  name     = var.name
  location = var.location
  project  = var.project_id

  template {
    template {
      service_account = var.service_account_email

      containers {
        image = var.image

        dynamic "env" {
          for_each = var.env
          content {
            name  = env.key
            value = env.value
          }
        }

        env {
          name = "SLACK_WEBHOOK_URL"
          value_source {
            secret_key_ref {
              secret  = var.slack_secret_name
              version = "latest"
            }
          }
        }
      }
    }
  }
}

output "name" {
  description = "Cloud Run Job name"
  value       = google_cloud_run_v2_job.this.name
}
