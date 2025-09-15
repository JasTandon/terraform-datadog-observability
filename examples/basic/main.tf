terraform {
  required_version = ">= 1.4.0"
  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = ">= 3.30.0"
    }
  }
}

provider "datadog" {}

module "dd" {
  source = "../.."

  monitors = [{
    name    = "High CPU"
    type    = "query alert"
    query   = "avg(last_5m):avg:aws.ec2.cpuutilization{env:dev} > 80"
    message = "CPU high on env:dev. @pagerduty"
    thresholds = { critical = 80, warning = 70 }
  }]

  dashboards = {
    "Golden – Demo" = {
      spec = {
        title       = "Golden – Demo"
        layout_type = "ordered"
        widgets = [{
          definition = {
            type = "timeseries"
            requests = [{
              queries = [{ data_source = "metrics", name = "q1", query = "avg:aws.ec2.cpuutilization{*}" }]
              display_type = "line"
            }]
            title = "EC2 CPU"
          }
        }]
      }
    }
  }

  synthetics = [{
    name        = "Homepage"
    type        = "api"
    subtype     = "http"
    request_url = "https://example.com/"
    request_method = "GET"
    locations   = ["aws:us-east-1"]
    assertions  = [{ type = "statusCode", operator = "is", target = 200 }]
  }]

  log_indexes = [{
    name = "dev-index"
    filter_query = "env:dev"
    retention_days = 7
  }]

  log_metrics = [{
    name = "web.5xx.count"
    filter_query = "service:web status:5xx"
    compute_aggregation = "count"
  }]

  aws_integration = {
    enabled     = false
    account_id  = null
    role_name   = null
    filter_tags = []
    host_tags   = []
  }
}
