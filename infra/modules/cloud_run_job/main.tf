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

variable "secrets" {
  type        = map(string)
  description = "Map of environment variable names to Secret Manager secret resource names (e.g., {SLACK_WEBHOOK_URL = \"projects/.../secrets/...\", LINE_CHANNEL_ACCESS_TOKEN = \"projects/.../secrets/...\"})"
  default     = {}
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

        dynamic "env" {
          for_each = var.secrets
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
      }
    }
  }
}

output "name" {
  description = "Cloud Run Job name"
  value       = google_cloud_run_v2_job.this.name
}
