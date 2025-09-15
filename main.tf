########################################
# Dashboards (via raw JSON resource)
########################################
resource "datadog_dashboard_json" "this" {
  for_each  = var.dashboards
  dashboard = coalesce(each.value.raw_json, jsonencode(each.value.spec))
}

########################################
# Monitors (alarms)
########################################
resource "datadog_monitor" "this" {
  for_each            = { for m in var.monitors : m.name => m }

  name                = each.value.name
  type                = each.value.type
  query               = each.value.query
  message             = each.value.message
  tags                = try(each.value.tags, [])
  priority            = try(each.value.priority, null)
  notify_no_data      = try(each.value.notify_no_data, false)
  no_data_timeframe   = try(each.value.no_data_timeframe, null)
  renotify_interval   = try(each.value.renotify_interval, null)
  include_tags        = try(each.value.include_tags, true)
  require_full_window = try(each.value.require_full_window, true)
  evaluation_delay    = try(each.value.evaluation_delay, null)

  dynamic "thresholds" {
    for_each = each.value.thresholds == null ? [] : [each.value.thresholds]
    content {
      critical          = try(thresholds.value.critical, null)
      warning           = try(thresholds.value.warning, null)
      critical_recovery = try(thresholds.value.critical_recovery, null)
      warning_recovery  = try(thresholds.value.warning_recovery, null)
      ok                = try(thresholds.value.ok, null)
    }
  }
}

########################################
# Synthetics (API HTTP)
########################################
resource "datadog_synthetics_test" "this" {
  for_each = { for s in var.synthetics : s.name => s }

  type    = each.value.type       # "api"
  subtype = each.value.subtype    # "http"
  name    = each.value.name
  tags    = try(each.value.tags, [])
  locations = each.value.locations
  status    = "live"

  request_definition {
    method = each.value.request_method
    url    = each.value.request_url
  }

  request_headers = try(each.value.request_headers, {})

  options_list {
    tick_every         = try(each.value.tick_every, 300)
    min_location_failed= try(each.value.min_location_failed, 1)
    follow_redirects   = try(each.value.follow_redirects, true)

    dynamic "retry" {
      for_each = try(each.value.retry, null) == null ? [] : [each.value.retry]
      content {
        count    = retry.value.count
        interval = retry.value.interval
      }
    }
  }

  dynamic "assertion" {
    for_each = try(each.value.assertions, [])
    content {
      type     = assertion.value.type
      operator = assertion.value.operator
      target   = assertion.value.target
    }
  }
}

########################################
# Logs — Indexes
########################################
resource "datadog_logs_index" "this" {
  for_each       = { for i in var.log_indexes : i.name => i }

  name           = each.value.name
  daily_limit    = try(each.value.daily_limit, null)
  retention_days = try(each.value.retention_days, null)

  dynamic "filter" {
    for_each = try(each.value.filter_query, null) == null ? [] : [each.value.filter_query]
    content {
      query = filter.value
    }
  }
}

########################################
# Logs — Log-based metrics
########################################
resource "datadog_logs_metric" "this" {
  for_each = { for m in var.log_metrics : m.name => m }

  name = each.value.name

  compute {
    aggregation = each.value.compute_aggregation
  }

  dynamic "filter" {
    for_each = try(each.value.filter_query, null) == null ? [] : [each.value.filter_query]
    content {
      query = filter.value
    }
  }

  dynamic "group_by" {
    for_each = try(each.value.group_bys, [])
    content {
      path = group_by.value.path
    }
  }
}

########################################
# Optional: Datadog ↔ AWS Integration (Datadog side)
########################################
resource "datadog_integration_aws_account" "this" {
  account_id = var.aws_integration.account_id
  role_name  = var.aws_integration.role_name

  # optional fields vary by provider version (regions, namespace rules, etc.)
  filter_tags = try(var.aws_integration.filter_tags, [])
  host_tags   = try(var.aws_integration.host_tags, [])
}

############################################################
# SYNTHETICS: Browser tests, global variables, private locations
############################################################

# Private Locations (optional)
resource "datadog_synthetics_private_location" "this" {
  for_each    = { for pl in var.synthetics_private_locations : pl.name => pl }
  name        = each.value.name
  description = try(each.value.description, null)
  tags        = try(each.value.tags, null)
}

# Synthetics Global Variables (optional)
resource "datadog_synthetics_global_variable" "this" {
  for_each    = { for v in var.synthetics_global_variables : v.name => v }
  name        = each.value.name
  description = try(each.value.description, null)

  # Either set a static value...
  value = try(each.value.value, null)

  # ...or parse from a test (if provided)
  dynamic "parse_test_options" {
    for_each = try(each.value.parse_test) != null ? [each.value.parse_test] : []
    content {
      type  = parse_test_options.value.type     # "raw" | "json_path" | "regex" | "x_path"
      value = try(parse_test_options.value.value, null)
    }
  }
  parse_test_id = try(each.value.parse_test.id, null)
}

# Browser tests
resource "datadog_synthetics_test" "browser" {
  for_each = { for t in var.synthetics_browser_tests : t.name => t }

  name       = each.value.name
  type       = "browser"
  subtype    = "browser"
  status     = coalesce(try(each.value.status, null), "live")
  tags       = try(each.value.tags, null)
  locations  = coalesce(try(each.value.locations, null), ["aws:us-east-1"])

  # Starting URL for the browser test
  request_definition {
    method = "GET"
    url    = each.value.start_url
  }

  # Options
  options_list {
    tick_every = coalesce(try(each.value.tick_every, null), 900)

    # For browser tests device_ids belong in options_list
    device_ids = coalesce(try(each.value.device_ids, null), ["laptop_large"])

    dynamic "retry" {
      for_each = try(each.value.retry) != null ? [each.value.retry] : []
      content {
        count    = try(retry.value.count, null)
        interval = try(retry.value.interval, null)
      }
    }

    dynamic "monitor_options" {
      for_each = try(each.value.monitor_options) != null ? [each.value.monitor_options] : []
      content {
        renotify_interval  = try(monitor_options.value.renotify_interval, null)
        escalation_message = try(monitor_options.value.escalation_message, null)
        notify_audit       = try(monitor_options.value.notify_audit, null)
        notify_no_data     = try(monitor_options.value.notify_no_data, null)
        no_data_timeframe  = try(monitor_options.value.no_data_timeframe, null)
        include_tags       = try(monitor_options.value.include_tags, null)
        require_full_window = try(monitor_options.value.require_full_window, null)
        new_group_delay    = try(monitor_options.value.new_group_delay, null)
        evaluation_delay   = try(monitor_options.value.evaluation_delay, null)
        timeout_h          = try(monitor_options.value.timeout_h, null)
      }
    }
  }

  # Local/browser variables (text, email, global via id, etc.)
  dynamic "browser_variable" {
    for_each = try(each.value.config_variables, [])
    content {
      type    = browser_variable.value.type          # "text" | "email" | "global" | ...
      name    = browser_variable.value.name
      id      = try(browser_variable.value.id, null) # required if type="global"
      value   = try(browser_variable.value.value, null)
      secure  = try(browser_variable.value.secure, false)
      example = try(browser_variable.value.example, null)
      pattern = try(browser_variable.value.pattern, null)
    }
  }

  # Steps
  dynamic "browser_step" {
    for_each = try(each.value.steps, [])
    content {
      type          = browser_step.value.type
      name          = try(browser_step.value.name, null)
      params        = try(browser_step.value.params, null)        # map(any) — matches Datadog step schema
      allow_failure = try(browser_step.value.allow_failure, null)
      is_critical   = try(browser_step.value.is_critical, null)
      timeout       = try(browser_step.value.timeout, null)
      no_screenshot = try(browser_step.value.no_screenshot, null)
    }
  }
}

############################################################
# DOWNTIME(S)
# Note: datadog_downtime_schedule is the modern resource; the legacy
#       datadog_downtime is simpler. Enable either via variables.
############################################################

# Simple/legacy downtimes (start/end epoch seconds)
resource "datadog_downtime" "this" {
  for_each = { for d in var.legacy_downtimes : d.name => d }

  scope   = each.value.scope              # list(string), e.g. ["env:prod"] or ["*"]
  message = try(each.value.message, null)
  start   = each.value.start              # epoch seconds
  end     = try(each.value.end, null)     # epoch seconds (optional)

  dynamic "recurrence" {
    for_each = try(each.value.recurrence) != null ? [each.value.recurrence] : []
    content {
      type               = recurrence.value.type        # "days" | "weeks" | "months" | "years"
      period             = recurrence.value.period
      week_days          = try(recurrence.value.week_days, null)
      until_date         = try(recurrence.value.until_date, null)
      until_occurrences  = try(recurrence.value.until_occurrences, null)
    }
  }
}

# (Optional) Monitor Config Policies — tag policies enforcement
resource "datadog_monitor_config_policy" "this" {
  for_each   = { for p in var.monitor_config_policies : p.name => p }
  policy_type = "tag"

  tag_policy {
    tag_key          = each.value.tag_key
    tag_key_required = coalesce(try(each.value.tag_key_required, null), false)
    valid_tag_values = try(each.value.valid_tag_values, null)
  }
}

############################################################
# SLOs
############################################################

resource "datadog_service_level_objective" "this" {
  for_each    = { for s in var.slos : s.name => s }
  name        = each.value.name
  type        = each.value.type                 # "metric" | "monitor"
  description = try(each.value.description, null)
  tags        = try(each.value.tags, null)

  # Metric-based SLO
  dynamic "query" {
    for_each = each.value.type == "metric" ? [true] : []
    content {
      numerator   = each.value.metric.numerator
      denominator = each.value.metric.denominator
    }
  }

  # Monitor-based SLO
  monitor_ids = each.value.type == "monitor" ? each.value.monitor.monitor_ids : null

  # Thresholds
  dynamic "thresholds" {
    for_each = try(each.value.thresholds, [])
    content {
      timeframe = thresholds.value.timeframe   # "7d" | "30d" | "90d" | "week" | "month" | ...
      target    = thresholds.value.target
      warning   = try(thresholds.value.warning, null)
    }
  }
}

############################################################
# METRICS: Metadata + Tag Config
############################################################

# Metric metadata (units, description, etc.)
resource "datadog_metric_metadata" "this" {
  for_each    = { for m in var.metric_metadata : m.metric => m }
  metric      = each.value.metric
  description = try(each.value.description, null)
  unit        = try(each.value.unit, null)
  short_name  = try(each.value.short_name, null)
  per_unit    = try(each.value.per_unit, null)
  type        = try(each.value.type, null)            # "count" | "gauge" | "rate" | "distribution" (update limitations apply)
  statsd_interval = try(each.value.statsd_interval, null)
}

# Metric tag configuration (queryable tags, aggregations, percentiles)
resource "datadog_metric_tag_configuration" "this" {
  for_each           = { for c in var.metric_tag_config : c.metric_name => c }
  metric_name        = each.value.metric_name
  metric_type        = each.value.metric_type         # "gauge" | "count" | "rate" | "distribution"
  tags               = try(each.value.tags, null)
  include_percentiles = try(each.value.include_percentiles, null)
  exclude_tags_mode   = try(each.value.exclude_tags_mode, null)

  dynamic "aggregations" {
    for_each = try(each.value.aggregations, [])
    content {
      time  = try(aggregations.value.time, null)      # e.g., "avg","sum","min","max"
      space = try(aggregations.value.space, null)     # e.g., "avg","sum","min","max"
    }
  }
}

############################################################
# LOGS: Archives + Pipelines (+ ordering)
############################################################

# Logs Archives (supports S3 / Azure / GCS)
resource "datadog_logs_archive" "this" {
  for_each = { for a in var.logs_archives : a.name => a }

  name  = each.value.name
  query = try(each.value.query, null)

  include_tags                = try(each.value.include_tags, null)
  rehydration_max_scan_size_in_gb = try(each.value.rehydration_max_scan_size_in_gb, null)
  rehydration_tags            = try(each.value.rehydration_tags, null)

  # S3
  dynamic "s3_archive" {
    for_each = try(each.value.s3) != null ? [each.value.s3] : []
    content {
      bucket             = s3_archive.value.bucket
      path               = try(s3_archive.value.path, null)
      account_id         = try(s3_archive.value.account_id, null)
      role_name          = try(s3_archive.value.role_name, null)
      iam_role_arn       = try(s3_archive.value.iam_role_arn, null) # alternative to account_id+role_name
      kms_key_arn        = try(s3_archive.value.kms_key_arn, null)
      storage_class      = try(s3_archive.value.storage_class, null) # e.g., "STANDARD_IA"
    }
  }

  # Azure
  dynamic "azure_archive" {
    for_each = try(each.value.azure) != null ? [each.value.azure] : []
    content {
      container         = azure_archive.value.container
      storage_account   = azure_archive.value.storage_account
      tenant_id         = try(azure_archive.value.tenant_id, null)
      client_id         = try(azure_archive.value.client_id, null)
      client_secret     = try(azure_archive.value.client_secret, null)
      path              = try(azure_archive.value.path, null)
    }
  }

  # GCS
  dynamic "gcs_archive" {
    for_each = try(each.value.gcs) != null ? [each.value.gcs] : []
    content {
      bucket   = gcs_archive.value.bucket
      path     = try(gcs_archive.value.path, null)
      client_email = try(gcs_archive.value.client_email, null)
      project_id   = try(gcs_archive.value.project_id, null)
      private_key  = try(gcs_archive.value.private_key, null)
    }
  }
}

# Optional: control global archive order
resource "datadog_logs_archive_order" "this" {
  count = length(var.logs_archive_order) > 0 ? 1 : 0
  archive_ids = [
    for name in var.logs_archive_order : datadog_logs_archive.this[name].id
  ]
}

# Logs Custom Pipelines (generic shape; add processors as needed)
resource "datadog_logs_custom_pipeline" "this" {
  for_each   = { for p in var.logs_custom_pipelines : p.name => p }
  name       = each.value.name
  is_enabled = coalesce(try(each.value.is_enabled, null), true)

  dynamic "filter" {
    for_each = try(each.value.filter) != null ? [each.value.filter] : []
    content {
      query = try(filter.value.query, null)
    }
  }

  # Example of enabling common processor kinds dynamically (extend as needed)
  dynamic "processor" {
    for_each = try(each.value.processors, [])
    content {
      type       = processor.value.type        # e.g., "grok-parser", "date-remapper", "status-remapper", "attribute-remapper", ...
      name       = try(processor.value.name, null)
      is_enabled = coalesce(try(processor.value.is_enabled, null), true)

      # GROK Parser
      dynamic "grok_parser" {
        for_each = can(processor.value.grok_parser) ? [processor.value.grok_parser] : []
        content {
          match_rules   = grok_parser.value.match_rules
          support_rules = try(grok_parser.value.support_rules, null)
        }
      }

      # Date Remapper
      dynamic "date_remapper" {
        for_each = can(processor.value.date_remapper) ? [processor.value.date_remapper] : []
        content {
          sources = date_remapper.value.sources
          target  = try(date_remapper.value.target, null)
        }
      }

      # Status Remapper
      dynamic "status_remapper" {
        for_each = can(processor.value.status_remapper) ? [processor.value.status_remapper] : []
        content {
          sources = status_remapper.value.sources
        }
      }

      # Attribute Remapper
      dynamic "attribute_remapper" {
        for_each = can(processor.value.attribute_remapper) ? [processor.value.attribute_remapper] : []
        content {
          sources               = attribute_remapper.value.sources
          source_type           = try(attribute_remapper.value.source_type, null)
          target                = try(attribute_remapper.value.target, null)
          target_type           = try(attribute_remapper.value.target_type, null)
          preserve_source       = try(attribute_remapper.value.preserve_source, null)
          override_on_conflict  = try(attribute_remapper.value.override_on_conflict, null)
          replace_missing       = try(attribute_remapper.value.replace_missing, null)
          ignore_missing        = try(attribute_remapper.value.ignore_missing, null)
        }
      }
    }
  }
}

# Optional: global pipeline order (top to bottom)
resource "datadog_logs_pipeline_order" "this" {
  count = length(var.logs_pipeline_order) > 0 ? 1 : 0
  pipeline_ids = [
    for name in var.logs_pipeline_order : datadog_logs_custom_pipeline.this[name].id
  ]
}

############################################################
# DASHBOARD LISTS
############################################################

resource "datadog_dashboard_list" "this" {
  for_each = { for l in var.dashboard_lists : l.name => l }
  name     = each.value.name

  # Optionally attach dashboards into each list
  dynamic "dash_item" {
    for_each = try(each.value.dash_items, [])
    content {
      dash_id = dash_item.value.dash_id  # ID of an existing datadog_dashboard / datadog_dashboard_json
      type    = try(dash_item.value.type, null)  # often optional/ignored
    }
  }
}
