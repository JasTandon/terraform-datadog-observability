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
  for_each = { for m in var.monitors : m.name => m }

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

  # Alert thresholds of the monitor
  dynamic "monitor_thresholds" {
    for_each = each.value.thresholds == null ? [] : [each.value.thresholds]
    content {
      critical          = try(monitor_thresholds.value.critical, null)
      warning           = try(monitor_thresholds.value.warning, null)
      critical_recovery = try(monitor_thresholds.value.critical_recovery, null)
      warning_recovery  = try(monitor_thresholds.value.warning_recovery, null)
      ok                = try(monitor_thresholds.value.ok, null)
    }
  }
}

########################################
# Synthetics (API HTTP)
########################################
resource "datadog_synthetics_test" "this" {
  for_each = { for s in var.synthetics : s.name => s }

  type      = each.value.type    # "api"
  subtype   = each.value.subtype # "http", "ssl", "tcp", etc.
  name      = each.value.name
  tags      = try(each.value.tags, [])
  locations = each.value.locations
  status    = "live"

  request_definition {
    method = each.value.request_method
    url    = each.value.request_url
  }

  request_headers = try(each.value.request_headers, {})

  options_list {
    tick_every          = try(each.value.tick_every, 300)
    min_location_failed = try(each.value.min_location_failed, 1)
    follow_redirects    = try(each.value.follow_redirects, true)

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
  for_each = { for i in var.log_indexes : i.name => i }

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
    # "count" or "distribution"
    aggregation_type = each.value.compute_aggregation
    # required when aggregation_type = "distribution"
    path = try(each.value.compute_path, null)
    # optional, only for "distribution"
    include_percentiles = try(each.value.include_percentiles, null)
  }

  dynamic "filter" {
    for_each = try(each.value.filter_query, null) == null ? [] : [each.value.filter_query]
    content { query = filter.value }
  }

  dynamic "group_by" {
    for_each = try(each.value.group_bys, [])
    content {
      path     = group_by.value.path
      tag_name = group_by.value.tag_name
    }
  }
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
  value       = try(each.value.value, null)
  secure      = try(each.value.secure, null)
  tags        = try(each.value.tags, null)
}

# Browser tests
resource "datadog_synthetics_test" "browser" {
  for_each = { for t in var.synthetics_browser_tests : t.name => t }

  name = each.value.name
  type = "browser"
  # IMPORTANT: no subtype for browser tests
  status    = coalesce(try(each.value.status, null), "live")
  tags      = try(each.value.tags, null)
  locations = coalesce(try(each.value.locations, null), ["aws:us-east-1"])

  # required for browser tests
  device_ids = coalesce(try(each.value.device_ids, null), ["laptop_large"])

  request_definition {
    method = "GET"
    url    = each.value.start_url
  }

  options_list {
    tick_every          = coalesce(try(each.value.tick_every, null), 900)
    min_location_failed = coalesce(try(each.value.min_location_failed, null), 1)

    dynamic "retry" {
      for_each = try(each.value.retry) != null ? [each.value.retry] : []
      content {
        count    = try(retry.value.count, null)
        interval = try(retry.value.interval, null)
      }
    }
  }

  # Optional config variables (no "value" field here)
  dynamic "config_variable" {
    for_each = try(each.value.config_variables, [])
    content {
      type    = config_variable.value.type
      name    = config_variable.value.name
      id      = try(config_variable.value.id, null) # required if type="global"
      secure  = try(config_variable.value.secure, null)
      example = try(config_variable.value.example, null)
      pattern = try(config_variable.value.pattern, null)
    }
  }
}

############################################################
# ✅ Downtimes (new resource; replaces deprecated datadog_downtime)
#    Builds one-time schedules from legacy epoch inputs.
############################################################
resource "datadog_downtime_schedule" "from_legacy" {
  for_each = { for d in var.legacy_downtimes : d.name => d }

  message          = try(each.value.message, null)
  display_timezone = null
  scope            = try(each.value.scope, null)

  # REQUIRED in current provider versions:
  # Use all monitors (for the given scope) by default.
  monitor_identifier {
    monitor_tags = ["*"]
  }

  one_time_schedule {
    # Convert epoch seconds to RFC3339 with UTC offset using timeadd()
    start = timeadd("1970-01-01T00:00:00Z", format("%ds", each.value.start))
    end   = try(each.value.end, null) != null ? timeadd("1970-01-01T00:00:00Z", format("%ds", each.value.end)) : null
  }
}

# (Optional) Monitor Config Policies — tag policies enforcement
resource "datadog_monitor_config_policy" "this" {
  for_each    = { for p in var.monitor_config_policies : p.name => p }
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
  type        = each.value.type # "metric" | "monitor"
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
      timeframe = thresholds.value.timeframe # "7d" | "30d" | "90d" | "week" | "month" | ...
      target    = thresholds.value.target
      warning   = try(thresholds.value.warning, null)
    }
  }
}

############################################################
# METRICS: Metadata + Tag Config
############################################################
resource "datadog_metric_metadata" "this" {
  for_each        = { for m in var.metric_metadata : m.metric => m }
  metric          = each.value.metric
  description     = try(each.value.description, null)
  unit            = try(each.value.unit, null)
  short_name      = try(each.value.short_name, null)
  per_unit        = try(each.value.per_unit, null)
  type            = try(each.value.type, null) # "count" | "gauge" | "rate" | "distribution"
  statsd_interval = try(each.value.statsd_interval, null)
}

resource "datadog_metric_tag_configuration" "this" {
  for_each            = { for c in var.metric_tag_config : c.metric_name => c }
  metric_name         = each.value.metric_name
  metric_type         = each.value.metric_type # "gauge" | "count" | "rate" | "distribution"
  tags                = try(each.value.tags, null)
  include_percentiles = try(each.value.include_percentiles, null)
  exclude_tags_mode   = try(each.value.exclude_tags_mode, null)

  dynamic "aggregations" {
    for_each = try(each.value.aggregations, [])
    content {
      time  = try(aggregations.value.time, null)  # e.g., "avg","sum","min","max"
      space = try(aggregations.value.space, null) # e.g., "avg","sum","min","max"
    }
  }
}

############################################################
# LOGS: Archives (+ ordering)
############################################################
resource "datadog_logs_archive" "this" {
  for_each = { for a in var.logs_archives : a.name => a }

  name  = each.value.name
  query = try(each.value.query, null)

  include_tags                    = try(each.value.include_tags, null)
  rehydration_max_scan_size_in_gb = try(each.value.rehydration_max_scan_size_in_gb, null)
  rehydration_tags                = try(each.value.rehydration_tags, null)

  # S3 destination
  dynamic "s3_archive" {
    for_each = try(each.value.s3) != null ? [each.value.s3] : []
    content {
      bucket     = s3_archive.value.bucket
      path       = try(s3_archive.value.path, null)
      account_id = s3_archive.value.account_id
      role_name  = s3_archive.value.role_name
    }
  }

  # Azure destination
  dynamic "azure_archive" {
    for_each = try(each.value.azure) != null ? [each.value.azure] : []
    content {
      container       = azure_archive.value.container
      storage_account = azure_archive.value.storage_account
      client_id       = azure_archive.value.client_id
      tenant_id       = try(azure_archive.value.tenant_id, null)
      path            = try(azure_archive.value.path, null)
    }
  }
}

resource "datadog_logs_archive_order" "this" {
  count = length(var.logs_archive_order) > 0 ? 1 : 0
  archive_ids = [
    for name in var.logs_archive_order : datadog_logs_archive.this[name].id
  ]
}

############################################################
# LOGS: Custom Pipelines (+ order)
############################################################
resource "datadog_logs_custom_pipeline" "this" {
  for_each   = { for p in var.logs_custom_pipelines : p.name => p }
  name       = each.value.name
  is_enabled = coalesce(try(each.value.is_enabled, null), true)

  # optional filter
  dynamic "filter" {
    for_each = try(each.value.filter) != null ? [each.value.filter] : []
    content {
      query = try(filter.value.query, null)
    }
  }

  # one or more processors
  dynamic "processor" {
    for_each = try(each.value.processors, [])
    content {
      # GROK Parser
      dynamic "grok_parser" {
        for_each = can(processor.value.grok_parser) ? [processor.value.grok_parser] : []
        content {
          source     = try(grok_parser.value.source, "message")
          name       = try(grok_parser.value.name, null)
          is_enabled = coalesce(try(grok_parser.value.is_enabled, null), true)

          grok {
            match_rules   = grok_parser.value.match_rules
            support_rules = try(grok_parser.value.support_rules, null)
          }
        }
      }

      # Date Remapper
      dynamic "date_remapper" {
        for_each = can(processor.value.date_remapper) ? [processor.value.date_remapper] : []
        content {
          sources    = date_remapper.value.sources
          name       = try(date_remapper.value.name, null)
          is_enabled = coalesce(try(date_remapper.value.is_enabled, null), true)
        }
      }

      # Status Remapper
      dynamic "status_remapper" {
        for_each = can(processor.value.status_remapper) ? [processor.value.status_remapper] : []
        content {
          sources    = status_remapper.value.sources
          name       = try(status_remapper.value.name, null)
          is_enabled = coalesce(try(status_remapper.value.is_enabled, null), true)
        }
      }

      # Attribute Remapper
      dynamic "attribute_remapper" {
        for_each = can(processor.value.attribute_remapper) ? [processor.value.attribute_remapper] : []
        content {
          sources              = attribute_remapper.value.sources
          source_type          = try(attribute_remapper.value.source_type, null)
          target               = try(attribute_remapper.value.target, null)
          target_type          = try(attribute_remapper.value.target_type, null)
          preserve_source      = try(attribute_remapper.value.preserve_source, null)
          override_on_conflict = try(attribute_remapper.value.override_on_conflict, null)
          name                 = try(attribute_remapper.value.name, null)
          is_enabled           = coalesce(try(attribute_remapper.value.is_enabled, null), true)
        }
      }
    }
  }
}

resource "datadog_logs_pipeline_order" "this" {
  count     = length(var.logs_pipeline_order) > 0 ? 1 : 0
  name      = "global-order"
  pipelines = var.logs_pipeline_order
}

############################################################
# DASHBOARD LISTS
############################################################
resource "datadog_dashboard_list" "this" {
  for_each = { for l in var.dashboard_lists : l.name => l }
  name     = each.value.name

  dynamic "dash_item" {
    for_each = try(each.value.dash_items, [])
    content {
      dash_id = dash_item.value.dash_id
      type    = try(dash_item.value.type, null)
    }
  }
}