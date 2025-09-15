variable "monitors" {
  description = <<EOT
List of Datadog monitors (alarms).
- name (string)
- type (string) e.g., "query alert", "log alert", "service check"
- query (string)
- message (string)
- tags (list(string))
- priority (number 1..5)
- notify_no_data (bool)
- no_data_timeframe (number, minutes)
- renotify_interval (number, minutes)
- include_tags (bool)
- require_full_window (bool)
- evaluation_delay (number, seconds)
- thresholds (object: critical, warning, critical_recovery, warning_recovery, ok)
EOT
  type = list(object({
    name                 = string
    type                 = string
    query                = string
    message              = string
    tags                 = optional(list(string), [])
    priority             = optional(number)
    notify_no_data       = optional(bool, false)
    no_data_timeframe    = optional(number)
    renotify_interval    = optional(number)
    include_tags         = optional(bool, true)
    require_full_window  = optional(bool, true)
    evaluation_delay     = optional(number)
    thresholds = optional(object({
      critical           = optional(number)
      warning            = optional(number)
      critical_recovery  = optional(number)
      warning_recovery   = optional(number)
      ok                 = optional(number)
    }), null)
  }))
  default = []
}

variable "dashboards" {
  description = "Map of dashboards. Provide raw JSON `raw_json` OR a `spec` object which will be jsonencoded."
  type = map(object({
    raw_json = optional(string)
    spec     = optional(any)
  }))
  default = {}
}

variable "synthetics" {
  description = <<EOT
List of Datadog synthetics tests (API HTTP).
- name, type="api", subtype="http"
- request_url, request_method
- request_headers (map), assertions (list of {type,operator,target})
- locations (list), tags (list)
- tick_every (seconds), min_location_failed (int), follow_redirects (bool)
- retry { count, interval(ms) }
EOT
  type = list(object({
    name       = string
    type       = string
    subtype    = string
    request_url     = string
    request_method  = string
    request_headers = optional(map(string), {})
    assertions      = optional(list(object({
      type     = string
      operator = string
      target   = any
    })), [])
    locations          = list(string)
    tags               = optional(list(string), [])
    tick_every         = optional(number, 300)
    min_location_failed= optional(number, 1)
    follow_redirects   = optional(bool, true)
    retry = optional(object({
      count    = number
      interval = number
    }), null)
  }))
  default = []
}

variable "log_indexes" {
  description = "List of log indexes."
  type = list(object({
    name           = string
    filter_query   = optional(string)
    retention_days = optional(number)
    daily_limit    = optional(number)
  }))
  default = []
}

variable "log_metrics" {
  description = "List of log-based metrics."
  type = list(object({
    name                = string
    filter_query        = optional(string)
    compute_aggregation = string                # e.g., count, distribution
    group_bys           = optional(list(object({
      path = string
    })), [])
  }))
  default = []
}

variable "aws_integration" {
  description = "Optional Datadog↔AWS integration config (Datadog side only)."
  type = object({
    enabled     = bool
    account_id  = optional(string)
    role_name   = optional(string)
    filter_tags = optional(list(string), [])
    host_tags   = optional(list(string), [])
    # NOTE: You must create/configure the AWS IAM role separately (trust Datadog, external ID).
  })
  default = {
    enabled     = false
    account_id  = null
    role_name   = null
    filter_tags = []
    host_tags   = []
  }
}
