variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Region for Cloud Run Job (e.g. asia-northeast1)"
  default     = "asia-northeast1"
}

variable "job_name" {
  type        = string
  description = "Cloud Run Job name"
  default     = "zutool-notifier-job"
}

variable "zutool_place_id" {
  type        = string
  description = "Zutool place ID (ZUTOOL_PLACE_ID)"
}

variable "pressure_level_threshold" {
  type        = number
  description = "PRESSURE_LEVEL_THRESHOLD (0-4)"
  default     = 3
}

variable "always_notify" {
  type        = bool
  description = "If true, ALWAYS_NOTIFY is set to true and notification is sent even without alert slots"
  default     = false
}

variable "line_user_id" {
  type        = string
  description = "LINE_USER_ID (optional)"
  default     = ""
}

variable "scheduler_region" {
  type        = string
  description = "Region for Cloud Scheduler job (must support Cloud Scheduler, e.g. asia-northeast1)"
}

variable "scheduler_name" {
  type        = string
  description = "Cloud Scheduler job name"
  default     = "zutool-notifier-schedule"
}

variable "scheduler_cron" {
  type        = string
  description = "Cron expression for Cloud Scheduler (e.g. 0 22 * * * for 7:00 JST if region is UTC+0)"
}

variable "scheduler_time_zone" {
  type        = string
  description = "Time zone for Cloud Scheduler (e.g. Asia/Tokyo)"
  default     = "Asia/Tokyo"
}

variable "slack_secret_version" {
  type        = string
  description = "Secret Manager secret version for SLACK_WEBHOOK_URL (e.g., 'latest', '1', '2'). Defaults to 'latest' for convenience, but consider using a specific version in production for better control."
  default     = "latest"
}
