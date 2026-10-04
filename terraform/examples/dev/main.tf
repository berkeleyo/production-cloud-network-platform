terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

module "network" {
  source = "../../modules/network"

  resource_group_name = "rg-synth-platform-dev"
  location            = "uksouth"

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
    "ManagementSubnet" = {
      address_prefixes              = ["10.10.20.0/24"]
      purpose                       = "management"
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
    name                       = "AllowCustomHubIngress"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.20.0.0/16"
    destination_address_prefix = "10.10.0.0/16"
    description                = "Reference-only rule for hub service access."
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
    description                = "Reference-only App Gateway backend rule."
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

module "ingress" {
  source = "../../modules/ingress"

  name                = "agw-synth-platform-dev"
  resource_group_name = module.network.resource_group_name
  location            = "uksouth"
  subnet_id           = module.network.application_subnet_ids["AppGatewaySubnet"]

  backend_pool_addresses = ["10.20.0.10", "10.20.10.10"]
  backend_port           = 443
  backend_host           = "app.internal.synthetic"
  health_path            = "/health"
  frontend_port          = 443

  tls = {
    name     = "simulated-platform-cert"
    data     = base64encode("synthetic-platform-cert-data")
    password = "replace-with-synthetic-password"
  }

  waf_enabled = true
  waf_mode    = "Prevention"
}
