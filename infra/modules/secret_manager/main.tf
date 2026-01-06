variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "secret_id" {
  type        = string
  description = "Secret ID (name) in Secret Manager"
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to the secret"
  default     = {}
}

resource "google_secret_manager_secret" "this" {
  project   = var.project_id
  secret_id = var.secret_id

  replication {
	auto {}
  }

  labels = var.labels
}

output "id" {
  description = "Full resource ID of the secret"
  value       = google_secret_manager_secret.this.id
}

output "name" {
  description = "Resource name of the secret"
  value       = google_secret_manager_secret.this.name
}
