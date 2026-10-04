locals {
  reserved_subnet_names = [
    "AzureFirewallSubnet",
    "AzureFirewallManagementSubnet",
    "GatewaySubnet",
    "AzureBastionSubnet",
  ]

  module_owned_deny_all_name     = "DenyAllInbound"
  module_owned_deny_all_priority = 4096

  app_gateway_subnet_cidr = try(var.application_subnets["AppGatewaySubnet"].address_prefixes[0], null)

  default_hub_nsg_rules = [
    {
      name                       = "AllowIngressFromApp"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.20.0.0/16"
      destination_address_prefix = "10.10.0.0/16"
      description                = "Reference-only rule allowing HTTPS from the application spoke."
    },
    {
      name                       = local.module_owned_deny_all_name
      priority                   = local.module_owned_deny_all_priority
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Module-owned deny baseline for ordinary hub traffic."
    }
  ]

  default_application_nsg_rules = local.app_gateway_subnet_cidr == null ? [
    {
      name                       = local.module_owned_deny_all_name
      priority                   = local.module_owned_deny_all_priority
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Module-owned deny baseline for ordinary workload traffic."
    }
    ] : [
    {
      name                       = "AllowHttpsFromAppGatewaySubnet"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = local.app_gateway_subnet_cidr
      destination_address_prefix = var.application_address_space[0]
      description                = "Allow HTTPS ingress from the dedicated App Gateway subnet."
    },
    {
      name                       = local.module_owned_deny_all_name
      priority                   = local.module_owned_deny_all_priority
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Module-owned deny baseline for ordinary workload traffic."
    }
  ]

  effective_hub_nsg_rules         = concat(local.default_hub_nsg_rules, var.hub_nsg_rules)
  effective_application_nsg_rules = concat(local.default_application_nsg_rules, var.application_nsg_rules)

  hub_nsg_rule_map = {
    for rule in local.effective_hub_nsg_rules : rule.name => rule
  }

  application_nsg_rule_map = {
    for rule in local.effective_application_nsg_rules : rule.name => rule
  }

  app_gateway_nsg_rule_map = {
    for rule in var.app_gateway_nsg_rules : rule.name => rule
  }
}

resource "azurerm_resource_group" "platform" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = var.hub_name
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  address_space       = var.hub_address_space
  tags                = var.tags
}

resource "azurerm_virtual_network" "application_spoke" {
  name                = var.application_spoke_name
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  address_space       = var.application_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "hub" {
  for_each = var.hub_subnets

  name                 = each.key
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = each.value.address_prefixes
}

resource "azurerm_subnet" "application" {
  for_each = var.application_subnets

  name                 = each.key
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.application_spoke.name
  address_prefixes     = each.value.address_prefixes
}

resource "azurerm_network_security_group" "hub" {
  name                = "nsg-${var.hub_name}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = var.tags
}

resource "azurerm_network_security_group" "application" {
  name                = "nsg-${var.application_spoke_name}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = var.tags
}

resource "azurerm_network_security_group" "app_gateway" {
  name                = "nsg-${var.application_spoke_name}-appgw"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "hub" {
  for_each = local.hub_nsg_rule_map

  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = azurerm_resource_group.platform.name
  network_security_group_name = azurerm_network_security_group.hub.name
  description                 = each.value.description
}

resource "azurerm_network_security_rule" "application" {
  for_each = local.application_nsg_rule_map

  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = azurerm_resource_group.platform.name
  network_security_group_name = azurerm_network_security_group.application.name
  description                 = each.value.description
}

resource "azurerm_network_security_rule" "app_gateway" {
  for_each = local.app_gateway_nsg_rule_map

  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = azurerm_resource_group.platform.name
  network_security_group_name = azurerm_network_security_group.app_gateway.name
  description                 = each.value.description
}

resource "azurerm_subnet_network_security_group_association" "hub" {
  for_each = {
    for key, subnet in var.hub_subnets : key => subnet
    if subnet.associate_default_nsg && !contains(local.reserved_subnet_names, key)
  }

  subnet_id                 = azurerm_subnet.hub[each.key].id
  network_security_group_id = azurerm_network_security_group.hub.id
}

resource "azurerm_subnet_network_security_group_association" "application" {
  for_each = {
    for key, subnet in var.application_subnets : key => subnet
    if key != "AppGatewaySubnet" && subnet.associate_default_nsg && !contains(local.reserved_subnet_names, key)
  }

  subnet_id                 = azurerm_subnet.application[each.key].id
  network_security_group_id = azurerm_network_security_group.application.id
}

resource "azurerm_subnet_network_security_group_association" "app_gateway" {
  for_each = {
    for key, subnet in var.application_subnets : key => subnet
    if key == "AppGatewaySubnet"
  }

  subnet_id                 = azurerm_subnet.application[each.key].id
  network_security_group_id = azurerm_network_security_group.app_gateway.id
}

resource "azurerm_route_table" "hub" {
  for_each = var.hub_route_tables

  name                          = each.key
  location                      = azurerm_resource_group.platform.location
  resource_group_name           = azurerm_resource_group.platform.name
  bgp_route_propagation_enabled = !each.value.disable_bgp_route_propagation
  tags                          = var.tags

  dynamic "route" {
    for_each = each.value.routes
    content {
      name                   = route.value.name
      address_prefix         = route.value.address_prefix
      next_hop_type          = route.value.next_hop_type
      next_hop_in_ip_address = route.value.next_hop_in_ip_address
    }
  }
}

resource "azurerm_route_table" "application" {
  for_each = var.application_route_tables

  name                          = each.key
  location                      = azurerm_resource_group.platform.location
  resource_group_name           = azurerm_resource_group.platform.name
  bgp_route_propagation_enabled = !each.value.disable_bgp_route_propagation
  tags                          = var.tags

  dynamic "route" {
    for_each = each.value.routes
    content {
      name                   = route.value.name
      address_prefix         = route.value.address_prefix
      next_hop_type          = route.value.next_hop_type
      next_hop_in_ip_address = route.value.next_hop_in_ip_address
    }
  }
}

resource "azurerm_subnet_route_table_association" "hub" {
  for_each = {
    for key, subnet in var.hub_subnets : key => subnet
    if subnet.associate_default_route_table && !contains(local.reserved_subnet_names, key)
  }

  subnet_id      = azurerm_subnet.hub[each.key].id
  route_table_id = azurerm_route_table.hub["hub-default"].id
}

resource "azurerm_subnet_route_table_association" "application" {
  for_each = {
    for key, subnet in var.application_subnets : key => subnet
    if key != "AppGatewaySubnet" && subnet.associate_default_route_table && !contains(local.reserved_subnet_names, key)
  }

  subnet_id      = azurerm_subnet.application[each.key].id
  route_table_id = azurerm_route_table.application["app-default"].id
}

resource "azurerm_virtual_network_peering" "hub_to_application" {
  name                         = "peer-${var.hub_name}-to-${var.application_spoke_name}"
  resource_group_name          = azurerm_resource_group.platform.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.application_spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "application_to_hub" {
  name                         = "peer-${var.application_spoke_name}-to-${var.hub_name}"
  resource_group_name          = azurerm_resource_group.platform.name
  virtual_network_name         = azurerm_virtual_network.application_spoke.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
