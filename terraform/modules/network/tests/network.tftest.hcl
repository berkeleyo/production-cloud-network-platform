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
    hub_nsg_rules = [{
      name                       = "AllowFromSpoke"
      priority                   = 150
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "1024-65535"
      destination_port_range     = "443"
      source_address_prefix      = "10.20.0.0/16"
      destination_address_prefix = "10.10.0.0/16"
      description                = "Synthetic allow rule."
    }]
    web_nsg_rules = [{
      name                       = "AllowCustomWebIngress"
      priority                   = 150
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "1024-65535"
      destination_port_range     = "443"
      source_address_prefix      = "10.20.30.0/24"
      destination_address_prefix = "10.20.0.0/24"
      description                = "Allow App Gateway back-end HTTPS."
    }]
    api_nsg_rules = [{
      name                       = "AllowCustomApiIngress"
      priority                   = 150
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "1024-65535"
      destination_port_range     = "443"
      source_address_prefix      = "10.20.0.0/24"
      destination_address_prefix = "10.20.10.0/24"
      description                = "Allow Web to API HTTPS."
    }]
    data_nsg_rules = [{
      name                       = "AllowCustomDataIngress"
      priority                   = 150
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "1024-65535"
      destination_port_range     = "5432"
      source_address_prefix      = "10.20.10.0/24"
      destination_address_prefix = "10.20.20.0/24"
      description                = "Allow API to Data Postgres."
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
    condition     = contains(keys(output.web_nsg_rules), "DenyAllInbound")
    error_message = "The module-owned Web DenyAllInbound rule must remain present even when custom allow rules are supplied."
  }

  assert {
    condition     = contains(keys(output.api_nsg_rules), "DenyAllInbound")
    error_message = "The module-owned API DenyAllInbound rule must remain present."
  }

  assert {
    condition     = contains(keys(output.data_nsg_rules), "DenyAllInbound")
    error_message = "The module-owned Data DenyAllInbound rule must remain present."
  }

  assert {
    condition     = output.web_nsg_rules["AllowAppGatewayHttps"].source_address_prefix == "10.20.30.0/24"
    error_message = "The Web NSG must use the AppGatewaySubnet CIDR as the permitted source for TCP 443."
  }

  assert {
    condition     = output.api_nsg_rules["AllowWebHttps"].source_address_prefix == "10.20.0.0/24"
    error_message = "The API NSG must use the WebSubnet CIDR as the permitted source for TCP 443."
  }

  assert {
    condition     = output.data_nsg_rules["AllowApiPostgres"].source_address_prefix == "10.20.10.0/24"
    error_message = "The Data NSG must use the ApiSubnet CIDR as the permitted source for TCP 5432."
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
    web_nsg_rules = [{
      name                       = "AllowOpsSsh"
      priority                   = 150
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "1024-65535"
      destination_port_range     = "8443"
      source_address_prefix      = "10.20.40.0/24"
      destination_address_prefix = "10.20.0.0/24"
      description                = "Narrow admin access outside the standard trust path."
    }]
  }

  assert {
    condition     = contains(keys(output.web_nsg_rules), "AllowOpsSsh")
    error_message = "Caller extension must be retained for the Web tier."
  }

  assert {
    condition     = contains(keys(output.web_nsg_rules), "DenyAllInbound")
    error_message = "Caller extensions must not remove the module-owned Web deny baseline."
  }
}

run "rejects_module_deny_priority_collision" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    web_nsg_rules = [{
      name                       = "AllowAtModuleDenyPriority"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "1024-65535"
      destination_port_range     = "443"
      source_address_prefix      = "10.20.30.0/24"
      destination_address_prefix = "10.20.0.0/24"
      description                = "Invalid priority collision with module deny baseline."
    }]
  }

  expect_failures = [var.web_nsg_rules]
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
    web_nsg_rules = [{
      name                       = "BadRule"
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "1024-65535"
      destination_port_range     = "443"
      source_address_prefix      = "0.0.0.0/0"
      destination_address_prefix = "10.20.0.0/24"
      description                = "Bad rule."
    }]
  }

  expect_failures = [var.web_nsg_rules]
}

run "rejects_zero_prefix_cidr_equivalent" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    web_nsg_rules = [{
      name                       = "ZeroPrefixCIDR"
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "1024-65535"
      destination_port_range     = "443"
      source_address_prefix      = "10.0.0.0/0"
      destination_address_prefix = "10.20.0.0/24"
      description                = "Reject equivalent /0 IPv4 CIDR."
    }]
  }

  expect_failures = [var.web_nsg_rules]
}

run "rejects_ipv6_zero_prefix_cidr_equivalent" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    web_nsg_rules = [{
      name                       = "ZeroPrefixIPv6CIDR"
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "1024-65535"
      destination_port_range     = "443"
      source_address_prefix      = "2001:db8::/0"
      destination_address_prefix = "2001:db8:1::/64"
      description                = "Reject equivalent /0 IPv6 CIDR."
    }]
  }

  expect_failures = [var.web_nsg_rules]
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

run "mandatory_tier_associations_ignore_opt_out_flags" {
  command = plan

  variables {
    resource_group_name       = "rg-synth-platform-dev"
    location                  = "uksouth"
    hub_address_space         = ["10.10.0.0/16"]
    application_address_space = ["10.20.0.0/16"]
    application_subnets = {
      "WebSubnet" = {
        address_prefixes              = ["10.20.0.0/24"]
        purpose                       = "web-tier"
        associate_default_nsg         = false
        associate_default_route_table = false
      }
      "ApiSubnet" = {
        address_prefixes              = ["10.20.10.0/24"]
        purpose                       = "api-tier"
        associate_default_nsg         = false
        associate_default_route_table = false
      }
      "DataSubnet" = {
        address_prefixes              = ["10.20.20.0/24"]
        purpose                       = "data-tier"
        associate_default_nsg         = false
        associate_default_route_table = false
      }
      "AppGatewaySubnet" = {
        address_prefixes              = ["10.20.30.0/24"]
        purpose                       = "application-gateway"
        associate_default_nsg         = false
        associate_default_route_table = false
      }
    }
  }

  assert {
    condition     = contains(keys(output.application_subnet_nsg_associations), "WebSubnet")
    error_message = "WebSubnet must remain associated with the Web NSG even when associate_default_nsg is false."
  }

  assert {
    condition     = contains(keys(output.application_subnet_nsg_associations), "ApiSubnet")
    error_message = "ApiSubnet must remain associated with the API NSG even when associate_default_nsg is false."
  }

  assert {
    condition     = contains(keys(output.application_subnet_nsg_associations), "DataSubnet")
    error_message = "DataSubnet must remain associated with the Data NSG even when associate_default_nsg is false."
  }

  assert {
    condition     = contains(keys(output.application_subnet_route_associations), "WebSubnet")
    error_message = "WebSubnet must remain associated with the default workload route table even when associate_default_route_table is false."
  }

  assert {
    condition     = contains(keys(output.application_subnet_route_associations), "ApiSubnet")
    error_message = "ApiSubnet must remain associated with the default workload route table even when associate_default_route_table is false."
  }

  assert {
    condition     = contains(keys(output.application_subnet_route_associations), "DataSubnet")
    error_message = "DataSubnet must remain associated with the default workload route table even when associate_default_route_table is false."
  }
}

run "positive_changed_cidr_segmentation_regression" {
  command = plan

  variables {
    resource_group_name       = "rg-synth-platform-dev"
    location                  = "uksouth"
    hub_address_space         = ["10.10.0.0/16"]
    application_address_space = ["10.99.0.0/16"]
    application_subnets = {
      "WebSubnet" = {
        address_prefixes              = ["10.99.0.0/24"]
        purpose                       = "web-tier"
        associate_default_nsg         = true
        associate_default_route_table = true
      }
      "ApiSubnet" = {
        address_prefixes              = ["10.99.10.0/24"]
        purpose                       = "api-tier"
        associate_default_nsg         = true
        associate_default_route_table = true
      }
      "DataSubnet" = {
        address_prefixes              = ["10.99.20.0/24"]
        purpose                       = "data-tier"
        associate_default_nsg         = true
        associate_default_route_table = true
      }
      "AppGatewaySubnet" = {
        address_prefixes              = ["10.99.30.0/24"]
        purpose                       = "application-gateway"
        associate_default_nsg         = false
        associate_default_route_table = false
      }
    }
  }

  assert {
    condition     = contains(keys(output.application_subnet_nsg_associations), "WebSubnet")
    error_message = "WebSubnet must be associated with the Web NSG."
  }

  assert {
    condition     = contains(keys(output.application_subnet_nsg_associations), "ApiSubnet")
    error_message = "ApiSubnet must be associated with the API NSG."
  }

  assert {
    condition     = contains(keys(output.application_subnet_nsg_associations), "DataSubnet")
    error_message = "DataSubnet must be associated with the Data NSG."
  }

  assert {
    condition     = contains(keys(output.app_gateway_subnet_nsg_associations), "AppGatewaySubnet")
    error_message = "AppGatewaySubnet must be associated with the dedicated App Gateway NSG."
  }

  assert {
    condition = (
      output.web_nsg_rules["AllowAppGatewayHttps"].source_address_prefix == "10.99.30.0/24" &&
      output.web_nsg_rules["AllowAppGatewayHttps"].destination_address_prefix == "10.99.0.0/24" &&
      output.web_nsg_rules["AllowAppGatewayHttps"].destination_port_range == "443" &&
      output.web_nsg_rules["AllowAppGatewayHttps"].protocol == "Tcp" &&
      output.web_nsg_rules["AllowAppGatewayHttps"].access == "Allow" &&
      output.web_nsg_rules["AllowAppGatewayHttps"].direction == "Inbound"
    )
    error_message = "Web allow rule must match the changed AppGatewaySubnet -> WebSubnet TCP 443 path."
  }

  assert {
    condition = (
      output.api_nsg_rules["AllowWebHttps"].source_address_prefix == "10.99.0.0/24" &&
      output.api_nsg_rules["AllowWebHttps"].destination_address_prefix == "10.99.10.0/24" &&
      output.api_nsg_rules["AllowWebHttps"].destination_port_range == "443" &&
      output.api_nsg_rules["AllowWebHttps"].protocol == "Tcp" &&
      output.api_nsg_rules["AllowWebHttps"].access == "Allow" &&
      output.api_nsg_rules["AllowWebHttps"].direction == "Inbound"
    )
    error_message = "API allow rule must match the changed WebSubnet -> ApiSubnet TCP 443 path."
  }

  assert {
    condition = (
      output.data_nsg_rules["AllowApiPostgres"].source_address_prefix == "10.99.10.0/24" &&
      output.data_nsg_rules["AllowApiPostgres"].destination_address_prefix == "10.99.20.0/24" &&
      output.data_nsg_rules["AllowApiPostgres"].destination_port_range == "5432" &&
      output.data_nsg_rules["AllowApiPostgres"].protocol == "Tcp" &&
      output.data_nsg_rules["AllowApiPostgres"].access == "Allow" &&
      output.data_nsg_rules["AllowApiPostgres"].direction == "Inbound"
    )
    error_message = "Data allow rule must match the changed ApiSubnet -> DataSubnet TCP 5432 path."
  }

  assert {
    condition     = output.web_nsg_rules["DenyAllInbound"].priority == 4096
    error_message = "Web DenyAllInbound must remain at priority 4096."
  }

  assert {
    condition     = output.web_nsg_rules["DenyAllInbound"].direction == "Inbound"
    error_message = "Web DenyAllInbound direction must be Inbound."
  }

  assert {
    condition     = output.web_nsg_rules["DenyAllInbound"].access == "Deny"
    error_message = "Web DenyAllInbound access must be Deny."
  }

  assert {
    condition     = output.web_nsg_rules["DenyAllInbound"].protocol == "*"
    error_message = "Web DenyAllInbound protocol must be *."
  }

  assert {
    condition     = output.web_nsg_rules["DenyAllInbound"].source_address_prefix == "*"
    error_message = "Web DenyAllInbound source must be *."
  }

  assert {
    condition     = output.web_nsg_rules["DenyAllInbound"].destination_address_prefix == "*"
    error_message = "Web DenyAllInbound destination must be *."
  }

  assert {
    condition     = output.web_nsg_rules["DenyAllInbound"].destination_port_range == "*"
    error_message = "Web DenyAllInbound destination port must be *."
  }

  assert {
    condition = (
      output.api_nsg_rules["DenyAllInbound"].name == "DenyAllInbound" &&
      output.api_nsg_rules["DenyAllInbound"].priority == 4096 &&
      output.api_nsg_rules["DenyAllInbound"].direction == "Inbound" &&
      output.api_nsg_rules["DenyAllInbound"].access == "Deny" &&
      output.api_nsg_rules["DenyAllInbound"].protocol == "*" &&
      output.api_nsg_rules["DenyAllInbound"].source_address_prefix == "*" &&
      output.api_nsg_rules["DenyAllInbound"].destination_address_prefix == "*" &&
      output.api_nsg_rules["DenyAllInbound"].destination_port_range == "*"
    )
    error_message = "API DenyAllInbound must have the full module-owned deny baseline."
  }

  assert {
    condition = (
      output.data_nsg_rules["DenyAllInbound"].name == "DenyAllInbound" &&
      output.data_nsg_rules["DenyAllInbound"].priority == 4096 &&
      output.data_nsg_rules["DenyAllInbound"].direction == "Inbound" &&
      output.data_nsg_rules["DenyAllInbound"].access == "Deny" &&
      output.data_nsg_rules["DenyAllInbound"].protocol == "*" &&
      output.data_nsg_rules["DenyAllInbound"].source_address_prefix == "*" &&
      output.data_nsg_rules["DenyAllInbound"].destination_address_prefix == "*" &&
      output.data_nsg_rules["DenyAllInbound"].destination_port_range == "*"
    )
    error_message = "Data DenyAllInbound must have the full module-owned deny baseline."
  }

  assert {
    condition     = length(keys(output.web_nsg_rules)) == 2 && contains(keys(output.web_nsg_rules), "AllowAppGatewayHttps") && contains(keys(output.web_nsg_rules), "DenyAllInbound")
    error_message = "The Web tier must only include the generated baseline allow and deny rules when no caller extensions are set."
  }

  assert {
    condition     = length(keys(output.api_nsg_rules)) == 2 && contains(keys(output.api_nsg_rules), "AllowWebHttps") && contains(keys(output.api_nsg_rules), "DenyAllInbound")
    error_message = "The API tier must only include the generated baseline allow and deny rules when no caller extensions are set."
  }

  assert {
    condition     = length(keys(output.data_nsg_rules)) == 2 && contains(keys(output.data_nsg_rules), "AllowApiPostgres") && contains(keys(output.data_nsg_rules), "DenyAllInbound")
    error_message = "The Data tier must only include the generated baseline allow and deny rules when no caller extensions are set."
  }
}

run "rejects_virtualnetwork_service_tag_source" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    web_nsg_rules = [{
      name                       = "VirtualNetworkBadRule"
      priority                   = 150
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "1024-65535"
      destination_port_range     = "443"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "10.20.0.0/24"
      description                = "Reject service tag source."
    }]
  }

  expect_failures = [var.web_nsg_rules]
}

run "rejects_full_port_range" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    web_nsg_rules = [{
      name                       = "FullRangeRule"
      priority                   = 150
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "1024-65535"
      destination_port_range     = "0-65535"
      source_address_prefix      = "10.20.40.0/24"
      destination_address_prefix = "10.20.0.0/24"
      description                = "Reject full port range."
    }]
  }

  expect_failures = [var.web_nsg_rules]
}

run "rejects_wildcard_protocol" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    web_nsg_rules = [{
      name                       = "WildcardProtocolRule"
      priority                   = 150
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "1024-65535"
      destination_port_range     = "443"
      source_address_prefix      = "10.20.40.0/24"
      destination_address_prefix = "10.20.0.0/24"
      description                = "Reject wildcard protocol."
    }]
  }

  expect_failures = [var.web_nsg_rules]
}

run "rejects_module_owned_allow_name_collision" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    api_nsg_rules = [{
      name                       = "AllowWebHttps"
      priority                   = 150
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "1024-65535"
      destination_port_range     = "443"
      source_address_prefix      = "10.20.50.0/24"
      destination_address_prefix = "10.20.10.0/24"
      description                = "Reject duplicate module-owned allow name."
    }]
  }

  expect_failures = [var.api_nsg_rules]
}

run "rejects_module_owned_allow_priority_collision" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    api_nsg_rules = [{
      name                       = "CustomAllowApi"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "1024-65535"
      destination_port_range     = "443"
      source_address_prefix      = "10.20.50.0/24"
      destination_address_prefix = "10.20.10.0/24"
      description                = "Reject duplicate module-owned priority."
    }]
  }

  expect_failures = [var.api_nsg_rules]
}

run "rejects_extra_application_subnet_key" {
  command = plan

  variables {
    resource_group_name       = "rg-synth-platform-dev"
    application_address_space = ["10.20.0.0/16"]
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
      "WorkerSubnet" = {
        address_prefixes              = ["10.20.40.0/24"]
        purpose                       = "worker-tier"
        associate_default_nsg         = true
        associate_default_route_table = true
      }
    }
  }

  expect_failures = [var.application_subnets]
}
