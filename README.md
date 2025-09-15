# terraform-datadog-observability

Datadog **monitors (alarms)**, **dashboards**, **synthetics**, **log indexes**, and **log-based metrics** — with an **optional AWS integration** (Datadog ↔︎ AWS).

## Features
- **Monitors**: metric/log/query monitors with thresholds, no-data behavior, tags, priority.
- **Dashboards**: use raw JSON via `datadog_dashboard_json`.
- **Synthetics**: API HTTP tests (locations, assertions, retries, options).
- **Logs**: create log **indexes** and **log-based metrics**.
- **AWS integration (optional)**: configure the Datadog side (you provide AWS role).

## Usage

```hcl
provider "datadog" {
  # export DATADOG_API_KEY, DATADOG_APP_KEY, DATADOG_SITE (e.g., datadoghq.com)
}

module "dd" {
  source  = "JasTandon/observability/datadog"
  version = "0.1.0"

  monitors = [
    {
      name    = "High CPU"
      type    = "query alert"
      query   = "avg(last_5m):avg:aws.ec2.cpuutilization{env:dev,asg:my-asg} > 80"
      message = "ASG CPU high. @pagerduty"
      tags    = ["service:web","env:dev"]
      thresholds = {
        critical = 80
        warning  = 70
      }
      notify_no_data      = true
      no_data_timeframe   = 15
      renotify_interval   = 60
      priority            = 3
    }
  ]

  dashboards = {
    "My Team – Golden Signals" = {
      # Pass full Datadog dashboard JSON spec
      spec = {
        title       = "My Team – Golden Signals"
        description = "Golden signals overview"
        layout_type = "ordered"
        widgets = [
          {
            definition = {
              type = "timeseries"
              requests = [{
                queries = [{
                  query = "avg:aws.ec2.cpuutilization{env:dev} by {host}"
                  data_source = "metrics"
                  name = "query1"
                }]
                display_type = "line"
              }]
              title = "EC2 CPU"
            }
          }
        ]
      }
    }
  }

  synthetics = [
    {
      name       = "Homepage availability"
      type       = "api"
      subtype    = "http"
      request_url     = "https://example.com/"
      request_method  = "GET"
      locations       = ["aws:us-east-1","aws:eu-west-1"]
      tags            = ["service:web","env:prod"]
      tick_every      = 300
      min_location_failed = 1
      follow_redirects    = true
      assertions = [
        { type = "statusCode", operator = "is", target = 200 }
      ]
      retry = { count = 2, interval = 3000 }
    }
  ]

  log_indexes = [
    {
      name           = "prod-index"
      filter_query   = "env:prod"
      retention_days = 15
      daily_limit    = 50
    }
  ]

  log_metrics = [
    {
      name                  = "web.5xx.count"
      filter_query          = "service:web status:5xx"
      compute_aggregation   = "count"
      # group_bys = [{ path = "@http.method" }]
    }
  ]

  # Optional: Configure Datadog↔AWS integration (Datadog side)
  aws_integration = {
    enabled     = true
    account_id  = "123456789012"
    role_name   = "datadog-integration-role"
    filter_tags = ["env:prod"]
    host_tags   = ["owner:platform"]
  }
}
