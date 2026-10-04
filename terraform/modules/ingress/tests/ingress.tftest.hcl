mock_provider "azurerm" {}

run "valid_ingress_module" {
  command = plan

  variables {
    resource_group_name    = "rg-synth-platform-dev"
    location               = "uksouth"
    subnet_id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synth-platform-dev/providers/Microsoft.Network/virtualNetworks/vnet-synth-app/subnets/AppGatewaySubnet"
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
  }

  assert {
    condition     = output.application_gateway_name == "agw-synth-platform"
    error_message = "Expected the ingress gateway logical name to be set."
  }

  assert {
    condition     = output.waf_enabled == true
    error_message = "Expected WAF to remain enabled in the reference design."
  }

  assert {
    condition     = output.application_gateway_sku == "WAF_v2"
    error_message = "Expected the reference ingress to use the WAF_v2 SKU."
  }

  assert {
    condition     = output.ssl_policy_name == "AppGwSslPolicy20220101"
    error_message = "Expected the Application Gateway to use the supported predefined SSL policy."
  }

  assert {
    condition     = output.application_gateway_waf_enabled == true
    error_message = "Expected the resource to enable WAF."
  }
}

run "rejects_invalid_tls" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synth-platform-dev/providers/Microsoft.Network/virtualNetworks/vnet-synth-app/subnets/AppGatewaySubnet"
    tls = {
      name     = "simulated-platform-cert"
      data     = "not-base64-data"
      password = "replace-with-synthetic-password"
    }
  }

  expect_failures = [var.tls]
}

run "rejects_http_frontend_port" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synth-platform-dev/providers/Microsoft.Network/virtualNetworks/vnet-synth-app/subnets/AppGatewaySubnet"
    frontend_port       = 80
    tls = {
      name     = "simulated-platform-cert"
      data     = base64encode("synthetic-platform-cert-data")
      password = "replace-with-synthetic-password"
    }
  }

  expect_failures = [var.frontend_port]
}
