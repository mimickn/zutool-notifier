output "cloud_run_job_name" {
  description = "Cloud Run Job name"
  value       = module.cloud_run_job.name
}

output "scheduler_job_name" {
  description = "Cloud Scheduler job name"
  value       = module.scheduler.name
}

output "slack_secret_name" {
  description = "Secret Manager secret name for SLACK_WEBHOOK_URL"
  value       = module.slack_secret.name
}
