mock_provider "azurerm" {}

run "valid_network_module" {
  command = plan

  variables {
    resource_group_name       = "rg-synth-platform-dev"
    location                  = "uksouth"
    hub_address_space         = ["10.10.0.0/16"]
    application_address_space = ["10.20.0.0/16"]
    hub_subnets = {
      "AzureFirewallSubnet" = {
        address_prefixes              = ["10.10.0.0/24"]
        purpose                       = "security-inspection"
        associate_default_nsg         = true
        associate_default_route_table = true
      }
      "SharedServicesSubnet" = {
        address_prefixes              = ["10.10.10.0/24"]
        purpose                       = "shared-services"
        associate_default_nsg         = true
        associate_default_route_table = true
      }
    }
    application_subnets = {
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
      "AppGatewaySubnet" = {
        address_prefixes              = ["10.20.30.0/24"]
        purpose                       = "application-gateway"
        associate_default_nsg         = false
        associate_default_route_table = false
      }
    }
    hub_nsg_rules = [{
      name                       = "AllowFromSpoke"
      priority                   = 150
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.20.0.0/16"
      destination_address_prefix = "10.10.0.0/16"
      description                = "Synthetic allow rule."
    }]
    application_nsg_rules = [{
      name                       = "AllowCustomAppIngress"
      priority                   = 150
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.20.30.0/24"
      destination_address_prefix = "10.20.0.0/16"
      description                = "Allow App Gateway back-end HTTPS."
    }]
    application_route_tables = {
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
  }

  assert {
    condition     = output.hub_vnet_name == "vnet-synth-hub"
    error_message = "Expected the hub virtual network name to be set."
  }

  assert {
    condition     = output.application_default_route.next_hop_type == "VirtualAppliance"
    error_message = "The application default route must use VirtualAppliance."
  }

  assert {
    condition     = output.application_default_route.next_hop_in_ip_address == "10.10.0.4"
    error_message = "The default route next-hop IP must match the synthetic firewall/NVA path."
  }

  assert {
    condition     = contains(keys(output.app_gateway_subnet_nsg_associations), "AppGatewaySubnet")
    error_message = "The AppGatewaySubnet must receive the dedicated App Gateway NSG association."
  }

  assert {
    condition     = !contains(keys(output.application_subnet_route_associations), "AppGatewaySubnet")
    error_message = "The AppGatewaySubnet must not inherit the application default route table."
  }

  assert {
    condition     = !contains(keys(output.hub_subnet_nsg_associations), "AzureFirewallSubnet")
    error_message = "AzureFirewallSubnet must never receive the general hub NSG association."
  }

  assert {
    condition     = !contains(keys(output.hub_subnet_route_associations), "AzureFirewallSubnet")
    error_message = "AzureFirewallSubnet must never receive the general hub route-table association."
  }

  assert {
    condition     = contains(keys(output.application_nsg_rules), "DenyAllInbound")
    error_message = "The module-owned application DenyAllInbound rule must remain present even when custom allow rules are supplied."
  }

  assert {
    condition     = contains(keys(output.hub_nsg_rules), "DenyAllInbound")
    error_message = "The module-owned hub DenyAllInbound rule must remain present."
  }
}

run "custom_allow_rules_keep_module_owned_deny" {
  command = plan

  variables {
    resource_group_name       = "rg-synth-platform-dev"
    location                  = "uksouth"
    hub_address_space         = ["10.10.0.0/16"]
    application_address_space = ["10.20.0.0/16"]
    hub_nsg_rules = [{
      name                       = "AllowCustomHubIngress"
      priority                   = 150
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.20.0.0/16"
      destination_address_prefix = "10.10.10.0/24"
      description                = "Custom hub allow rule."
    }]
    application_nsg_rules = [{
      name                       = "AllowCustomAppIngress"
      priority                   = 150
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.20.30.0/24"
      destination_address_prefix = "10.20.0.0/16"
      description                = "Custom application allow rule."
    }]
  }

  assert {
    condition     = contains(keys(output.application_nsg_rules), "DenyAllInbound")
    error_message = "Custom application allow rules must not remove the module-owned DenyAllInbound baseline."
  }

  assert {
    condition     = contains(keys(output.hub_nsg_rules), "DenyAllInbound")
    error_message = "Custom hub allow rules must not remove the module-owned DenyAllInbound baseline."
  }
}

run "rejects_module_deny_priority_collision" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    application_nsg_rules = [{
      name                       = "AllowAtModuleDenyPriority"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "10.20.30.0/24"
      destination_address_prefix = "10.20.0.0/16"
      description                = "Invalid priority collision with module deny baseline."
    }]
  }

  expect_failures = [var.application_nsg_rules]
}

run "rejects_virtual_appliance_without_next_hop" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    application_route_tables = {
      "app-default" = {
        disable_bgp_route_propagation = false
        routes = [{
          name           = "default-to-future-hub-firewall"
          address_prefix = "0.0.0.0/0"
          next_hop_type  = "VirtualAppliance"
        }]
      }
    }
  }

  expect_failures = [var.application_route_tables]
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    resource_group_name       = "rg-synth-platform-dev"
    hub_address_space         = ["not-a-cidr"]
    application_address_space = ["10.20.0.0/16"]
  }

  expect_failures = [var.hub_address_space]
}

run "rejects_unsafe_unrestricted_source" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    application_nsg_rules = [{
      name                       = "BadRule"
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "0.0.0.0/0"
      destination_address_prefix = "10.20.0.0/16"
      description                = "Bad rule."
    }]
  }

  expect_failures = [var.application_nsg_rules]
}

run "rejects_invalid_app_gateway_service_tag_combination" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    app_gateway_nsg_rules = [{
      name                       = "BadGatewayRule"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "GatewayManager"
      destination_address_prefix = "*"
      description                = "Not allowed for App Gateway management traffic."
    }]
  }

  expect_failures = [var.app_gateway_nsg_rules]
}
