locals {
  reserved_subnet_names = [
    "AzureFirewallSubnet",
    "AzureFirewallManagementSubnet",
    "GatewaySubnet",
    "AzureBastionSubnet",
  ]

  required_application_subnet_keys = ["WebSubnet", "ApiSubnet", "DataSubnet", "AppGatewaySubnet"]

  module_owned_deny_all_name     = "DenyAllInbound"
  module_owned_deny_all_priority = 4096

  app_gateway_subnet_cidr = try(var.application_subnets["AppGatewaySubnet"].address_prefixes[0], null)
  web_subnet_cidr         = try(var.application_subnets["WebSubnet"].address_prefixes[0], null)
  api_subnet_cidr         = try(var.application_subnets["ApiSubnet"].address_prefixes[0], null)
  data_subnet_cidr        = try(var.application_subnets["DataSubnet"].address_prefixes[0], null)

  deny_all_rule = {
    name                       = local.module_owned_deny_all_name
    priority                   = local.module_owned_deny_all_priority
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Module-owned deny baseline for the tier."
  }

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
    local.deny_all_rule,
  ]

  default_web_nsg_rules = [
    {
      name                       = "AllowAppGatewayHttps"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "1024-65535"
      destination_port_range     = "443"
      source_address_prefix      = local.app_gateway_subnet_cidr
      destination_address_prefix = local.web_subnet_cidr
      description                = "Allow HTTPS from the dedicated App Gateway subnet to the Web tier."
    },
    local.deny_all_rule,
  ]

  default_api_nsg_rules = [
    {
      name                       = "AllowWebHttps"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "1024-65535"
      destination_port_range     = "443"
      source_address_prefix      = local.web_subnet_cidr
      destination_address_prefix = local.api_subnet_cidr
      description                = "Allow HTTPS from the Web tier to the API tier."
    },
    local.deny_all_rule,
  ]

  default_data_nsg_rules = [
    {
      name                       = "AllowApiPostgres"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "1024-65535"
      destination_port_range     = "5432"
      source_address_prefix      = local.api_subnet_cidr
      destination_address_prefix = local.data_subnet_cidr
      description                = "Allow PostgreSQL from the API tier to the Data tier."
    },
    local.deny_all_rule,
  ]

  effective_hub_nsg_rules  = concat(local.default_hub_nsg_rules, var.hub_nsg_rules)
  effective_web_nsg_rules  = concat(local.default_web_nsg_rules, var.web_nsg_rules)
  effective_api_nsg_rules  = concat(local.default_api_nsg_rules, var.api_nsg_rules)
  effective_data_nsg_rules = concat(local.default_data_nsg_rules, var.data_nsg_rules)

  hub_nsg_rule_map = {
    for rule in local.effective_hub_nsg_rules : rule.name => rule
  }

  web_nsg_rule_map = {
    for rule in local.effective_web_nsg_rules : rule.name => rule
  }

  api_nsg_rule_map = {
    for rule in local.effective_api_nsg_rules : rule.name => rule
  }

  data_nsg_rule_map = {
    for rule in local.effective_data_nsg_rules : rule.name => rule
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

resource "azurerm_network_security_group" "web" {
  name                = "nsg-${var.application_spoke_name}-web"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = var.tags
}

resource "azurerm_network_security_group" "api" {
  name                = "nsg-${var.application_spoke_name}-api"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = var.tags
}

resource "azurerm_network_security_group" "data" {
  name                = "nsg-${var.application_spoke_name}-data"
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

resource "azurerm_network_security_rule" "web" {
  for_each = local.web_nsg_rule_map

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
  network_security_group_name = azurerm_network_security_group.web.name
  description                 = each.value.description
}

resource "azurerm_network_security_rule" "api" {
  for_each = local.api_nsg_rule_map

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
  network_security_group_name = azurerm_network_security_group.api.name
  description                 = each.value.description
}

resource "azurerm_network_security_rule" "data" {
  for_each = local.data_nsg_rule_map

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
  network_security_group_name = azurerm_network_security_group.data.name
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

resource "azurerm_subnet_network_security_group_association" "web" {
  for_each = {
    for key in ["WebSubnet"] : key => var.application_subnets[key]
    if contains(keys(var.application_subnets), key) && !contains(local.reserved_subnet_names, key)
  }

  subnet_id                 = azurerm_subnet.application[each.key].id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_subnet_network_security_group_association" "api" {
  for_each = {
    for key in ["ApiSubnet"] : key => var.application_subnets[key]
    if contains(keys(var.application_subnets), key) && !contains(local.reserved_subnet_names, key)
  }

  subnet_id                 = azurerm_subnet.application[each.key].id
  network_security_group_id = azurerm_network_security_group.api.id
}

resource "azurerm_subnet_network_security_group_association" "data" {
  for_each = {
    for key in ["DataSubnet"] : key => var.application_subnets[key]
    if contains(keys(var.application_subnets), key) && !contains(local.reserved_subnet_names, key)
  }

  subnet_id                 = azurerm_subnet.application[each.key].id
  network_security_group_id = azurerm_network_security_group.data.id
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
    for key in ["WebSubnet", "ApiSubnet", "DataSubnet"] : key => var.application_subnets[key]
    if contains(keys(var.application_subnets), key) && !contains(local.reserved_subnet_names, key)
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
