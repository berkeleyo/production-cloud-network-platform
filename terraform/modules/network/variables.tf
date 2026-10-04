variable "resource_group_name" {
  description = "Synthetic resource group name for the reference platform environment."
  type        = string

  validation {
    condition     = length(trimspace(var.resource_group_name)) > 0
    error_message = "resource_group_name must not be empty."
  }
}

variable "location" {
  description = "Azure region name used for documentation and reference-only design examples."
  type        = string
  default     = "uksouth"

  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "location must not be empty."
  }
}

variable "tags" {
  description = "Synthetic tag map used for reference architecture examples."
  type        = map(string)
  default = {
    environment = "simulated"
    owner       = "portfolio"
    workload    = "cloud-network-platform"
  }
}

variable "hub_name" {
  description = "Logical hub VNet name."
  type        = string
  default     = "vnet-synth-hub"
}

variable "application_spoke_name" {
  description = "Logical application spoke VNet name."
  type        = string
  default     = "vnet-synth-app"
}

variable "hub_address_space" {
  description = "CIDR blocks assigned to the hub VNet. This is synthetic reference-only configuration."
  type        = list(string)
  default     = ["10.10.0.0/16"]

  validation {
    condition = length(var.hub_address_space) > 0 && alltrue([
      for cidr in var.hub_address_space : can(cidrhost(cidr, 0))
    ])
    error_message = "hub_address_space must contain at least one valid CIDR block."
  }
}

variable "application_address_space" {
  description = "CIDR blocks assigned to the application spoke VNet."
  type        = list(string)
  default     = ["10.20.0.0/16"]

  validation {
    condition = length(var.application_address_space) > 0 && alltrue([
      for cidr in var.application_address_space : can(cidrhost(cidr, 0))
    ])
    error_message = "application_address_space must contain at least one valid CIDR block."
  }
}

variable "hub_subnets" {
  description = "Map of synthetic hub subnets keyed by subnet name."
  type = map(object({
    address_prefixes              = list(string)
    purpose                       = string
    associate_default_nsg         = optional(bool, true)
    associate_default_route_table = optional(bool, true)
  }))

  default = {
    "AzureFirewallSubnet" = {
      address_prefixes              = ["10.10.0.0/24"]
      purpose                       = "security-inspection"
      associate_default_nsg         = true
      associate_default_route_table = true
    }
    "AzureFirewallManagementSubnet" = {
      address_prefixes              = ["10.10.1.0/24"]
      purpose                       = "firewall-management"
      associate_default_nsg         = true
      associate_default_route_table = true
    }
    "GatewaySubnet" = {
      address_prefixes              = ["10.10.2.0/24"]
      purpose                       = "gateway"
      associate_default_nsg         = true
      associate_default_route_table = true
    }
    "AzureBastionSubnet" = {
      address_prefixes              = ["10.10.3.0/24"]
      purpose                       = "bastion"
      associate_default_nsg         = true
      associate_default_route_table = true
    }
    "SharedServicesSubnet" = {
      address_prefixes              = ["10.10.10.0/24"]
      purpose                       = "shared-services"
      associate_default_nsg         = true
      associate_default_route_table = true
    }
    "ManagementSubnet" = {
      address_prefixes              = ["10.10.20.0/24"]
      purpose                       = "management"
      associate_default_nsg         = true
      associate_default_route_table = true
    }
  }

  validation {
    condition = alltrue([
      for subnet in values(var.hub_subnets) : length(subnet.address_prefixes) > 0 && alltrue([
        for cidr in subnet.address_prefixes : can(cidrhost(cidr, 0))
      ])
    ])
    error_message = "Each hub subnet must include at least one valid CIDR prefix."
  }
}

variable "application_subnets" {
  description = "Map of synthetic application spoke subnets keyed by subnet name."
  type = map(object({
    address_prefixes              = list(string)
    purpose                       = string
    associate_default_nsg         = optional(bool, true)
    associate_default_route_table = optional(bool, true)
  }))

  default = {
    "WebSubnet" = {
      address_prefixes              = ["10.20.0.0/24"]
      purpose                       = "web-tier"
      associate_default_nsg         = true
      associate_default_route_table = true
    }
    "ApiSubnet" = {
      address_prefixes              = ["10.20.10.0/24"]
      purpose                       = "api-tier"
      associate_default_nsg         = true
      associate_default_route_table = true
    }
    "DataSubnet" = {
      address_prefixes              = ["10.20.20.0/24"]
      purpose                       = "data-tier"
      associate_default_nsg         = true
      associate_default_route_table = true
    }
    "AppGatewaySubnet" = {
      address_prefixes              = ["10.20.30.0/24"]
      purpose                       = "application-gateway"
      associate_default_nsg         = false
      associate_default_route_table = false
    }
  }

  validation {
    condition = alltrue([
      for subnet in values(var.application_subnets) : length(subnet.address_prefixes) > 0 && alltrue([
        for cidr in subnet.address_prefixes : can(cidrhost(cidr, 0))
      ])
    ]) && length(keys(var.application_subnets)) == 4 && contains(keys(var.application_subnets), "WebSubnet") && contains(keys(var.application_subnets), "ApiSubnet") && contains(keys(var.application_subnets), "DataSubnet") && contains(keys(var.application_subnets), "AppGatewaySubnet") && length(setsubtract(keys(var.application_subnets), ["WebSubnet", "ApiSubnet", "DataSubnet", "AppGatewaySubnet"])) == 0
    error_message = "Application subnets must include exactly WebSubnet, ApiSubnet, DataSubnet, and AppGatewaySubnet; no extra spoke subnet keys are supported."
  }
}

variable "hub_nsg_rules" {
  description = "Additional deliberate allow rules for the hub VNet. The module owns the final inbound deny baseline."
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
    description                = string
  }))
  default = []

  validation {
    condition = (
      alltrue([
        for rule in var.hub_nsg_rules : (
          rule.access == "Allow" &&
          rule.direction == "Inbound" &&
          length(rule.name) > 0 &&
          rule.name != "AllowIngressFromApp" &&
          rule.name != "DenyAllInbound" &&
          rule.priority >= 100 &&
          rule.priority < 4096 &&
          rule.priority != 100 &&
          can(cidrhost(rule.source_address_prefix, 0)) &&
          can(cidrhost(rule.destination_address_prefix, 0)) &&
          tonumber(split("/", rule.source_address_prefix)[1]) > 0 &&
          tonumber(split("/", rule.destination_address_prefix)[1]) > 0 &&
          !contains(["VirtualNetwork", "Internet", "AzureCloud", "AzureLoadBalancer", "GatewayManager", "Any", "*"], rule.source_address_prefix) &&
          !contains(["VirtualNetwork", "Internet", "AzureCloud", "AzureLoadBalancer", "GatewayManager", "Any", "*"], rule.destination_address_prefix) &&
          (rule.protocol == "Tcp" || rule.protocol == "Udp") &&
          rule.source_port_range != "*" &&
          rule.source_port_range != "0-65535" &&
          rule.source_port_range != "1-65535" &&
          rule.destination_port_range != "*" &&
          rule.destination_port_range != "0-65535" &&
          rule.destination_port_range != "1-65535" &&
          rule.priority != 4096
        )
      ]) &&
      length(distinct([for rule in var.hub_nsg_rules : rule.name])) == length(var.hub_nsg_rules) &&
      length(distinct([for rule in var.hub_nsg_rules : rule.priority])) == length(var.hub_nsg_rules)
    )
    error_message = "Hub NSG custom rules must use narrow CIDR-based inbound Allow rules over Tcp or Udp; broad Azure trust and wildcard port ranges are rejected."
  }
}

variable "web_nsg_rules" {
  description = "Additional deliberate allow rules for the Web tier. The module owns the final inbound deny baseline."
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
    description                = string
  }))
  default = []

  validation {
    condition = (
      alltrue([
        for rule in var.web_nsg_rules : (
          rule.access == "Allow" &&
          rule.direction == "Inbound" &&
          length(rule.name) > 0 &&
          rule.name != "AllowAppGatewayHttps" &&
          rule.name != "DenyAllInbound" &&
          rule.priority >= 100 &&
          rule.priority < 4096 &&
          rule.priority != 100 &&
          can(cidrhost(rule.source_address_prefix, 0)) &&
          can(cidrhost(rule.destination_address_prefix, 0)) &&
          tonumber(split("/", rule.source_address_prefix)[1]) > 0 &&
          tonumber(split("/", rule.destination_address_prefix)[1]) > 0 &&
          !contains(["VirtualNetwork", "Internet", "AzureCloud", "AzureLoadBalancer", "GatewayManager", "Any", "*"], rule.source_address_prefix) &&
          !contains(["VirtualNetwork", "Internet", "AzureCloud", "AzureLoadBalancer", "GatewayManager", "Any", "*"], rule.destination_address_prefix) &&
          (rule.protocol == "Tcp" || rule.protocol == "Udp") &&
          rule.source_port_range != "*" &&
          rule.source_port_range != "0-65535" &&
          rule.source_port_range != "1-65535" &&
          rule.destination_port_range != "*" &&
          rule.destination_port_range != "0-65535" &&
          rule.destination_port_range != "1-65535" &&
          rule.priority != 4096
        )
      ]) &&
      length(distinct([for rule in var.web_nsg_rules : rule.name])) == length(var.web_nsg_rules) &&
      length(distinct([for rule in var.web_nsg_rules : rule.priority])) == length(var.web_nsg_rules)
    )
    error_message = "Web NSG custom rules must use narrow CIDR-based inbound Allow rules over Tcp or Udp; broad Azure trust and wildcard port ranges are rejected."
  }
}

variable "api_nsg_rules" {
  description = "Additional deliberate allow rules for the API tier. The module owns the final inbound deny baseline."
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
    description                = string
  }))
  default = []

  validation {
    condition = (
      alltrue([
        for rule in var.api_nsg_rules : (
          rule.access == "Allow" &&
          rule.direction == "Inbound" &&
          length(rule.name) > 0 &&
          rule.name != "AllowWebHttps" &&
          rule.name != "DenyAllInbound" &&
          rule.priority >= 100 &&
          rule.priority < 4096 &&
          rule.priority != 100 &&
          can(cidrhost(rule.source_address_prefix, 0)) &&
          can(cidrhost(rule.destination_address_prefix, 0)) &&
          tonumber(split("/", rule.source_address_prefix)[1]) > 0 &&
          tonumber(split("/", rule.destination_address_prefix)[1]) > 0 &&
          !contains(["VirtualNetwork", "Internet", "AzureCloud", "AzureLoadBalancer", "GatewayManager", "Any", "*"], rule.source_address_prefix) &&
          !contains(["VirtualNetwork", "Internet", "AzureCloud", "AzureLoadBalancer", "GatewayManager", "Any", "*"], rule.destination_address_prefix) &&
          (rule.protocol == "Tcp" || rule.protocol == "Udp") &&
          rule.source_port_range != "*" &&
          rule.source_port_range != "0-65535" &&
          rule.source_port_range != "1-65535" &&
          rule.destination_port_range != "*" &&
          rule.destination_port_range != "0-65535" &&
          rule.destination_port_range != "1-65535" &&
          rule.priority != 4096
        )
      ]) &&
      length(distinct([for rule in var.api_nsg_rules : rule.name])) == length(var.api_nsg_rules) &&
      length(distinct([for rule in var.api_nsg_rules : rule.priority])) == length(var.api_nsg_rules)
    )
    error_message = "API NSG custom rules must use narrow CIDR-based inbound Allow rules over Tcp or Udp; broad Azure trust and wildcard port ranges are rejected."
  }
}

variable "data_nsg_rules" {
  description = "Additional deliberate allow rules for the Data tier. The module owns the final inbound deny baseline."
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
    description                = string
  }))
  default = []

  validation {
    condition = (
      alltrue([
        for rule in var.data_nsg_rules : (
          rule.access == "Allow" &&
          rule.direction == "Inbound" &&
          length(rule.name) > 0 &&
          rule.name != "AllowApiPostgres" &&
          rule.name != "DenyAllInbound" &&
          rule.priority >= 100 &&
          rule.priority < 4096 &&
          rule.priority != 100 &&
          can(cidrhost(rule.source_address_prefix, 0)) &&
          can(cidrhost(rule.destination_address_prefix, 0)) &&
          tonumber(split("/", rule.source_address_prefix)[1]) > 0 &&
          tonumber(split("/", rule.destination_address_prefix)[1]) > 0 &&
          !contains(["VirtualNetwork", "Internet", "AzureCloud", "AzureLoadBalancer", "GatewayManager", "Any", "*"], rule.source_address_prefix) &&
          !contains(["VirtualNetwork", "Internet", "AzureCloud", "AzureLoadBalancer", "GatewayManager", "Any", "*"], rule.destination_address_prefix) &&
          (rule.protocol == "Tcp" || rule.protocol == "Udp") &&
          rule.source_port_range != "*" &&
          rule.source_port_range != "0-65535" &&
          rule.source_port_range != "1-65535" &&
          rule.destination_port_range != "*" &&
          rule.destination_port_range != "0-65535" &&
          rule.destination_port_range != "1-65535" &&
          rule.priority != 4096
        )
      ]) &&
      length(distinct([for rule in var.data_nsg_rules : rule.name])) == length(var.data_nsg_rules) &&
      length(distinct([for rule in var.data_nsg_rules : rule.priority])) == length(var.data_nsg_rules)
    )
    error_message = "Data NSG custom rules must use narrow CIDR-based inbound Allow rules over Tcp or Udp; broad Azure trust and wildcard port ranges are rejected."
  }
}

variable "app_gateway_nsg_rules" {
  description = "Dedicated NSG rules for the Application Gateway subnet."
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
    description                = string
  }))
  default = [
    {
      name                       = "AllowGatewayManager"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "65200-65535"
      source_address_prefix      = "GatewayManager"
      destination_address_prefix = "*"
      description                = "Allow Gateway Manager management traffic for the Application Gateway v2 subnet."
    },
    {
      name                       = "AllowAzureLoadBalancer"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "*"
      description                = "Allow Azure Load Balancer health checks to the Application Gateway subnet."
    },
    {
      name                       = "AllowHttpsFromInternet"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
      description                = "Allow public HTTPS ingress to the dedicated Application Gateway subnet."
    },
    {
      name                       = "DenyAllInbound"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Default deny for the dedicated Application Gateway subnet."
    }
  ]

  validation {
    condition = alltrue([
      for rule in var.app_gateway_nsg_rules : contains(["Inbound", "Outbound"], rule.direction) &&
      contains(["Allow", "Deny"], rule.access) &&
      length(rule.name) > 0 &&
      rule.priority >= 100 && rule.priority <= 4096 &&
      (rule.access == "Deny" || (
        (
          rule.source_address_prefix == "GatewayManager" &&
          rule.protocol == "Tcp" &&
          rule.destination_port_range == "65200-65535" &&
          rule.destination_address_prefix == "*"
          ) || (
          rule.source_address_prefix == "AzureLoadBalancer" &&
          rule.protocol == "Tcp" &&
          rule.destination_port_range == "*" &&
          rule.destination_address_prefix == "*"
          ) || (
          (rule.source_address_prefix == "Internet" || can(cidrhost(rule.source_address_prefix, 0))) &&
          rule.protocol == "Tcp" &&
          rule.destination_port_range == "443" &&
          rule.destination_address_prefix == "*"
        )
      ))
    ])
    error_message = "App Gateway NSG rules must permit only the intended GatewayManager, AzureLoadBalancer, and public HTTPS combinations."
  }
}

variable "hub_route_tables" {
  description = "Map of route tables for hub subnets."
  type = map(object({
    disable_bgp_route_propagation = bool
    routes = list(object({
      name                   = string
      address_prefix         = string
      next_hop_type          = string
      next_hop_in_ip_address = optional(string)
    }))
  }))
  default = {
    "hub-default" = {
      disable_bgp_route_propagation = false
      routes                        = []
    }
  }

  validation {
    condition = alltrue([
      for table in values(var.hub_route_tables) : alltrue([
        for route in table.routes : contains(["Internet", "VirtualAppliance", "VirtualNetworkGateway", "None"], route.next_hop_type) &&
        (route.next_hop_type != "VirtualAppliance" || can(cidrhost("${route.next_hop_in_ip_address}/32", 0)))
      ])
    ])
    error_message = "Route table next hop types must be explicit and VirtualAppliance routes must provide a next-hop IP."
  }
}

variable "application_route_tables" {
  description = "Map of route tables for application spoke subnets."
  type = map(object({
    disable_bgp_route_propagation = bool
    routes = list(object({
      name                   = string
      address_prefix         = string
      next_hop_type          = string
      next_hop_in_ip_address = optional(string)
    }))
  }))
  default = {
    "app-default" = {
      disable_bgp_route_propagation = false
      routes = [{
        name                   = "default-to-future-hub-firewall"
        address_prefix         = "0.0.0.0/0"
        next_hop_type          = "VirtualAppliance"
        next_hop_in_ip_address = "10.10.0.4"
      }]
    }
  }

  validation {
    condition = alltrue([
      for table in values(var.application_route_tables) : alltrue([
        for route in table.routes : contains(["Internet", "VirtualAppliance", "VirtualNetworkGateway", "None"], route.next_hop_type) &&
        (route.next_hop_type != "VirtualAppliance" || can(cidrhost("${route.next_hop_in_ip_address}/32", 0)))
      ])
    ])
    error_message = "Application route table definitions must use valid Azure next hop types and VirtualAppliance routes must include an explicit next-hop IP."
  }
}
