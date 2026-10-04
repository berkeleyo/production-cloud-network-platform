resource "azurerm_public_ip" "gateway" {
  name                = "pip-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_application_gateway" "platform" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  zones               = ["1", "2", "3"]
  tags                = var.tags

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  autoscale_configuration {
    min_capacity = 2
    max_capacity = 10
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name                 = "frontend-public-ip"
    public_ip_address_id = azurerm_public_ip.gateway.id
  }

  frontend_port {
    name = "https-port"
    port = var.frontend_port
  }

  backend_address_pool {
    name         = "app-backend-pool"
    ip_addresses = var.backend_pool_addresses
  }

  backend_http_settings {
    name                  = "https-settings"
    cookie_based_affinity = "Disabled"
    port                  = var.backend_port
    protocol              = "Https"
    request_timeout       = 60
    probe_name            = "backend-health"
  }

  ssl_certificate {
    name     = var.tls.name
    data     = var.tls.data
    password = var.tls.password
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "frontend-public-ip"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
    ssl_certificate_name           = var.tls.name
    require_sni                    = true
  }

  probe {
    name                = "backend-health"
    protocol            = "Https"
    path                = var.health_path
    host                = var.backend_host
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    port                = var.backend_port
  }

  request_routing_rule {
    name                       = "https-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "app-backend-pool"
    backend_http_settings_name = "https-settings"
    priority                   = 100
  }

  waf_configuration {
    enabled                  = true
    firewall_mode            = var.waf_mode
    rule_set_type            = "OWASP"
    rule_set_version         = "3.2"
    request_body_check       = true
    max_request_body_size_kb = 128
    file_upload_limit_mb     = 100
  }
}
