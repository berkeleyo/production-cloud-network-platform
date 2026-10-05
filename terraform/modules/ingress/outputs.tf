output "application_gateway_id" {
  description = "Resource ID of the synthetic Application Gateway."
  value       = azurerm_application_gateway.platform.id
}

output "application_gateway_name" {
  description = "Resource name of the synthetic Application Gateway."
  value       = azurerm_application_gateway.platform.name
}

output "application_gateway_sku" {
  description = "SKU name used by the synthetic Application Gateway."
  value       = azurerm_application_gateway.platform.sku[0].name
}

output "public_ip_address" {
  description = "Public IP used by the reference ingress layer."
  value       = azurerm_public_ip.gateway.ip_address
}

output "backend_pool_name" {
  description = "Name of the configured Application Gateway backend pool."
  value       = one(azurerm_application_gateway.platform.backend_address_pool).name
}

output "listener_name" {
  description = "Name of the HTTPS listener resource."
  value       = "https-listener"
}

output "waf_enabled" {
  description = "Whether WAF is enabled in the reference configuration."
  value       = var.waf_enabled
}

output "ssl_policy_name" {
  description = "The configured Application Gateway SSL policy name."
  value       = azurerm_application_gateway.platform.ssl_policy[0].policy_name
}

output "application_gateway_backend_hostname" {
  description = "The backend host name used by the Application Gateway HTTPS settings."
  value       = one(azurerm_application_gateway.platform.backend_http_settings).host_name
}

output "backend_trusted_root_certificate_name" {
  description = "The synthetic trusted-root certificate used for backend HTTPS validation."
  value       = one(azurerm_application_gateway.platform.trusted_root_certificate).name
  sensitive   = true
}

output "application_gateway_diagnostic_setting_name" {
  description = "The diagnostic setting name for the Application Gateway."
  value       = azurerm_monitor_diagnostic_setting.application_gateway.name
}

output "application_gateway_waf_enabled" {
  description = "Whether the Application Gateway resource is associated with an enabled WAF policy."
  value       = azurerm_application_gateway.platform.firewall_policy_id != null && var.waf_enabled
}

output "waf_policy_id" {
  description = "Resource ID of the dedicated Azure WAF policy."
  value       = azurerm_web_application_firewall_policy.platform.id
}

output "waf_policy_name" {
  description = "Resource name of the dedicated Azure WAF policy."
  value       = azurerm_web_application_firewall_policy.platform.name
}

output "waf_policy_mode" {
  description = "Configured operating mode for the dedicated Azure WAF policy."
  value       = azurerm_web_application_firewall_policy.platform.policy_settings[0].mode
}

output "waf_policy" {
  description = "The generated dedicated Azure WAF policy resource for offline validation and assertions."
  value       = azurerm_web_application_firewall_policy.platform
}
