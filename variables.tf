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
    name                = string
    type                = string
    query               = string
    message             = string
    tags                = optional(list(string), [])
    priority            = optional(number)
    notify_no_data      = optional(bool, false)
    no_data_timeframe   = optional(number)
    renotify_interval   = optional(number)
    include_tags        = optional(bool, true)
    require_full_window = optional(bool, true)
    evaluation_delay    = optional(number)
    thresholds = optional(object({
      critical          = optional(number)
      warning           = optional(number)
      critical_recovery = optional(number)
      warning_recovery  = optional(number)
      ok                = optional(number)
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
    name            = string
    type            = string
    subtype         = string
    request_url     = string
    request_method  = string
    request_headers = optional(map(string), {})
    assertions = optional(list(object({
      type     = string
      operator = string
      target   = any
    })), [])
    locations           = list(string)
    tags                = optional(list(string), [])
    tick_every          = optional(number, 300)
    min_location_failed = optional(number, 1)
    follow_redirects    = optional(bool, true)
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

# --- logs: metrics ---
variable "log_metrics" {
  description = "List of log-based metrics."
  type = list(object({
    name         = string
    filter_query = optional(string)

    # compute
    compute_aggregation = string           # "count" | "distribution"
    compute_path        = optional(string) # required for "distribution"
    include_percentiles = optional(bool)

    # groups
    group_bys = optional(list(object({
      path     = string
      tag_name = string
    })), [])
  }))
  default = []
}

# --- aws integration (classic resource) ---
variable "aws_integration" {
  description = "Datadog ↔ AWS (classic integration resource)."
  type = object({
    enabled                          = bool
    account_id                       = optional(string)
    role_name                        = optional(string)
    filter_tags                      = optional(list(string), [])
    host_tags                        = optional(list(string), [])
    account_specific_namespace_rules = optional(map(bool))
  })
  default = {
    enabled                          = false
    account_id                       = null
    role_name                        = null
    filter_tags                      = []
    host_tags                        = []
    account_specific_namespace_rules = null
  }
}

############################################################
# SYNTHETICS: Browser tests, global variables, private locations
############################################################

variable "synthetics_private_locations" {
  description = "List of private locations to create for Synthetics."
  type = list(object({
    name        = string
    description = optional(string)
    tags        = optional(list(string))
  }))
  default = []
}

# --- synthetics: globals ---
variable "synthetics_global_variables" {
  description = "Synthetics global variables (static values only)."
  type = list(object({
    name        = string
    description = optional(string)
    value       = optional(string)
    secure      = optional(bool)
    tags        = optional(list(string))
  }))
  default = []
}

# --- synthetics: browser tests (no steps for now) ---
variable "synthetics_browser_tests" {
  description = "Browser Synthetics tests (basic: start URL, schedule, locations)."
  type = list(object({
    name                = string
    start_url           = string
    locations           = optional(list(string))
    tags                = optional(list(string))
    status              = optional(string) # "live" | "paused"
    tick_every          = optional(number)
    min_location_failed = optional(number)
    device_ids          = optional(list(string)) # e.g., ["laptop_large"]

    retry = optional(object({
      count    = optional(number)
      interval = optional(number)
    }))

    # Optional config variables
    config_variables = optional(list(object({
      type    = string
      name    = string
      id      = optional(string) # required if type="global"
      secure  = optional(bool)
      example = optional(string)
      pattern = optional(string)
    })))
  }))
  default = []
}

############################################################
# DOWNTIME(S) + MONITOR CONFIG POLICIES
############################################################

# Legacy/simple downtimes (epoch seconds)
variable "legacy_downtimes" {
  description = "Simple downtimes using legacy resource (epoch start/end)."
  type = list(object({
    name    = string
    scope   = list(string) # e.g., ["*"] or ["env:prod"]
    message = optional(string)
    start   = number           # epoch secs
    end     = optional(number) # epoch secs

    recurrence = optional(object({
      type              = string # "days" | "weeks" | "months" | "years"
      period            = number
      week_days         = optional(list(string))
      until_date        = optional(number)
      until_occurrences = optional(number)
    }))
  }))
  default = []
}

variable "monitor_config_policies" {
  description = "Optional monitor config tag policies (org-level enforcement)."
  type = list(object({
    name             = string
    tag_key          = string
    tag_key_required = optional(bool)
    valid_tag_values = optional(list(string))
  }))
  default = []
}

############################################################
# SLOs
############################################################

variable "slos" {
  description = "Service Level Objectives."
  type = list(object({
    name        = string
    type        = string # "metric" | "monitor"
    description = optional(string)
    tags        = optional(list(string))

    metric = optional(object({
      numerator   = string
      denominator = string
    }))

    monitor = optional(object({
      monitor_ids = list(number)
    }))

    thresholds = list(object({
      timeframe = string # "7d" | "30d" | "90d" | "week" | "month" | ...
      target    = number
      warning   = optional(number)
    }))
  }))
  default = []
}

############################################################
# METRICS
############################################################

variable "metric_metadata" {
  description = "Metric metadata (units, descriptions, etc.)"
  type = list(object({
    metric          = string
    description     = optional(string)
    unit            = optional(string)
    short_name      = optional(string)
    per_unit        = optional(string)
    type            = optional(string) # "count" | "gauge" | "rate" | "distribution" (updates limited)
    statsd_interval = optional(number)
  }))
  default = []
}

variable "metric_tag_config" {
  description = "Metric tag configurations (queryable tag keys, aggregations, percentiles)."
  type = list(object({
    metric_name         = string
    metric_type         = string # "gauge" | "count" | "rate" | "distribution"
    tags                = optional(list(string))
    include_percentiles = optional(bool)
    exclude_tags_mode   = optional(bool)
    aggregations = optional(list(object({
      time  = optional(string) # e.g., "avg","sum","min","max"
      space = optional(string)
    })))
  }))
  default = []
}

############################################################
# LOGS: Archives + Pipelines
############################################################

# --- logs: archives ---
variable "logs_archives" {
  description = "Log archives (S3 and/or Azure)."
  type = list(object({
    name  = string
    query = optional(string)

    include_tags                    = optional(bool)
    rehydration_max_scan_size_in_gb = optional(number)
    rehydration_tags                = optional(list(string))

    s3 = optional(object({
      bucket     = string
      path       = optional(string)
      account_id = string
      role_name  = string
    }))

    azure = optional(object({
      container       = string
      storage_account = string
      client_id       = string
      tenant_id       = optional(string)
      path            = optional(string)
    }))
  }))
  default = []
}

# Explicit archive order (list of archive names you defined above)
variable "logs_archive_order" {
  description = "Optional explicit ordering of archives by name (top to bottom)."
  type        = list(string)
  default     = []
}

variable "logs_custom_pipelines" {
  description = "Custom log pipelines; add processors to shape logs. See README for processor shapes."
  type = list(object({
    name       = string
    is_enabled = optional(bool)

    filter = optional(object({
      query = optional(string)
    }))

    # A loose, typed bag for common processors; extend as needed per Datadog docs
    processors = optional(list(object({
      type       = string # "grok-parser" | "date-remapper" | "status-remapper" | "attribute-remapper" | ...
      name       = optional(string)
      is_enabled = optional(bool)

      grok_parser = optional(object({
        match_rules   = string
        support_rules = optional(string)
      }))

      date_remapper = optional(object({
        sources = list(string)
        target  = optional(string)
      }))

      status_remapper = optional(object({
        sources = list(string)
      }))

      attribute_remapper = optional(object({
        sources              = list(string)
        source_type          = optional(string)
        target               = optional(string)
        target_type          = optional(string)
        preserve_source      = optional(bool)
        override_on_conflict = optional(bool)
        replace_missing      = optional(bool)
        ignore_missing       = optional(bool)
      }))
    })))
  }))
  default = []
}

# --- logs: pipeline order (IDs, not names) ---
variable "logs_pipeline_order" {
  description = "Explicit order of pipelines by ID (top to bottom)."
  type        = list(string)
  default     = []
}

############################################################
# DASHBOARD LISTS
############################################################

variable "dashboard_lists" {
  description = "Dashboard lists and (optionally) the dashboards to include."
  type = list(object({
    name = string
    dash_items = optional(list(object({
      dash_id = string           # dashboard id (from datadog_dashboard or datadog_dashboard_json resource)
      type    = optional(string) # optional/ignored by Datadog in many cases
    })))
  }))
  default = []
}
