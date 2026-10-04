output "resource_group_name" {
  description = "Name of the synthetic resource group containing the platform network resources."
  value       = azurerm_resource_group.platform.name
}

output "hub_vnet_id" {
  description = "Resource ID of the hub VNet."
  value       = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  description = "Name of the hub VNet."
  value       = azurerm_virtual_network.hub.name
}

output "application_vnet_id" {
  description = "Resource ID of the application spoke VNet."
  value       = azurerm_virtual_network.application_spoke.id
}

output "application_vnet_name" {
  description = "Name of the application spoke VNet."
  value       = azurerm_virtual_network.application_spoke.name
}

output "hub_subnet_ids" {
  description = "Map of hub subnet IDs keyed by subnet name."
  value       = { for key, subnet in azurerm_subnet.hub : key => subnet.id }
}

output "application_subnet_ids" {
  description = "Map of application subnet IDs keyed by subnet name."
  value       = { for key, subnet in azurerm_subnet.application : key => subnet.id }
}

output "hub_subnet_nsg_associations" {
  description = "Map of hub subnets associated with the general hub NSG."
  value       = { for key, association in azurerm_subnet_network_security_group_association.hub : key => association.subnet_id }
}

output "hub_subnet_route_associations" {
  description = "Map of hub subnets associated with the general hub route table."
  value       = { for key, association in azurerm_subnet_route_table_association.hub : key => association.subnet_id }
}

output "application_subnet_nsg_associations" {
  description = "Map of application subnets associated with the general application NSG."
  value       = { for key, association in azurerm_subnet_network_security_group_association.application : key => association.subnet_id }
}

output "app_gateway_subnet_nsg_associations" {
  description = "Map of the dedicated App Gateway subnet associations to the AppGateway-specific NSG."
  value       = { for key, association in azurerm_subnet_network_security_group_association.app_gateway : key => association.subnet_id }
}

output "application_subnet_route_associations" {
  description = "Map of application subnets associated with the default workload route table."
  value       = { for key, association in azurerm_subnet_route_table_association.application : key => association.subnet_id }
}

output "application_default_route" {
  description = "The default application spoke route used for the synthetic firewall/NVA inspection path."
  value = one([
    for route in azurerm_route_table.application["app-default"].route : route
    if route.address_prefix == "0.0.0.0/0"
  ])
}

output "hub_nsg_id" {
  description = "Resource ID of the hub NSG."
  value       = azurerm_network_security_group.hub.id
}

output "application_nsg_id" {
  description = "Resource ID of the application NSG."
  value       = azurerm_network_security_group.application.id
}

output "app_gateway_nsg_id" {
  description = "Resource ID of the dedicated Application Gateway NSG."
  value       = azurerm_network_security_group.app_gateway.id
}

output "hub_nsg_rules" {
  description = "Map of hub NSG rules keyed by rule name. This exposes the actual module-owned deny baseline and allow rules for validation tests."
  value       = { for key, rule in azurerm_network_security_rule.hub : key => rule }
}

output "application_nsg_rules" {
  description = "Map of application NSG rules keyed by rule name. This exposes the actual module-owned deny baseline and allow rules for validation tests."
  value       = { for key, rule in azurerm_network_security_rule.application : key => rule }
}

output "peering_ids" {
  description = "Map of VNet peering resource IDs."
  value = {
    hub_to_application = azurerm_virtual_network_peering.hub_to_application.id
    application_to_hub = azurerm_virtual_network_peering.application_to_hub.id
  }
}
