output "monitor_ids" {
  description = "Datadog monitor IDs keyed by name"
  value       = { for k, v in datadog_monitor.this : k => v.id }
}

output "dashboard_ids" {
  description = "Datadog dashboard IDs keyed by title"
  value       = { for k, v in datadog_dashboard_json.this : k => v.id }
}

output "synthetics_public_ids" {
  description = "Synthetics public IDs keyed by name"
  value       = { for k, v in datadog_synthetics_test.this : k => v.public_id }
}

output "log_index_names" {
  description = "Created log indexes"
  value       = keys(datadog_logs_index.this)
}

output "log_metric_names" {
  description = "Created log-based metrics"
  value       = keys(datadog_logs_metric.this)
}
