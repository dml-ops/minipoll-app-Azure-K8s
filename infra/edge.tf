# Azure DNS zone. Like your Route 53 zone: afterwards you change the
# nameservers at Spaceship.
resource "azurerm_dns_zone" "zone" {
  name                = var.domain_name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_cdn_frontdoor_profile" "fd" {
  name                = "${var.project_name}-fd"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "ep" {
  name                     = "${var.project_name}-ep-${random_string.suffix.result}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id
}

resource "azurerm_cdn_frontdoor_origin_group" "og" {
  name                     = "aks"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id

  load_balancing {}

  health_probe {
    path                = "/healthz"
    protocol            = "Http"
    request_type        = "GET"
    interval_in_seconds = 100
  }
}

resource "azurerm_cdn_frontdoor_origin" "aks" {
  name                           = "aks-ingress"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.og.id
  host_name                      = var.ingress_ip
  http_port                      = 80
  certificate_name_check_enabled = false
  enabled                        = true
}

resource "azurerm_cdn_frontdoor_custom_domain" "cd" {
  name                     = "polls"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id
  dns_zone_id              = azurerm_dns_zone.zone.id
  host_name                = "polls.${var.domain_name}"

  tls {
    certificate_type = "ManagedCertificate"
  }
}

resource "azurerm_cdn_frontdoor_route" "route" {
  name                            = "default"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.ep.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.og.id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.aks.id]
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.cd.id]
  patterns_to_match               = ["/*"]
  supported_protocols             = ["Http", "Https"]
  https_redirect_enabled          = true # HTTP -> HTTPS redirect
  forwarding_protocol             = "HttpOnly"
  link_to_default_domain          = true
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "assoc" {
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.cd.id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.route.id]
}

# DNS records: point polls.<domain> at Front Door and prove you own it
resource "azurerm_dns_cname_record" "polls" {
  name                = "polls"
  zone_name           = azurerm_dns_zone.zone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  record              = azurerm_cdn_frontdoor_endpoint.ep.host_name
}

resource "azurerm_dns_txt_record" "validation" {
  name                = "_dnsauth.polls"
  zone_name           = azurerm_dns_zone.zone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300

  record {
    value = azurerm_cdn_frontdoor_custom_domain.cd.validation_token
  }
}

output "name_servers" {
  value = azurerm_dns_zone.zone.name_servers
}

output "frontdoor_hostname" {
  value = azurerm_cdn_frontdoor_endpoint.ep.host_name
}
