resource "azurerm_monitor_action_group" "email" {
  name                = "${var.project_name}-alerts"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "minipoll"

  email_receiver {
    name          = "me"
    email_address = var.alert_email
  }
}

resource "azurerm_monitor_metric_alert" "restarts" {
  name                = "${var.project_name}-container-restarts"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_kubernetes_cluster.aks.id]
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace       = "Insights.Container/pods"
    metric_name            = "restartingContainerCount"
    aggregation            = "Maximum"
    operator               = "GreaterThan"
    threshold              = 0
    skip_metric_validation = true # <--- Added this line
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }
}
