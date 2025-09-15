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
