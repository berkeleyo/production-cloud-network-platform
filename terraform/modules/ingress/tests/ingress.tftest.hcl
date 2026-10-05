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
    condition     = output.waf_policy_name == "waf-synth-platform"
    error_message = "Expected the dedicated WAF policy to use the synthetic default name."
  }

  assert {
    condition     = output.waf_policy_mode == "Prevention"
    error_message = "Expected the default WAF mode to be Prevention."
  }

  assert {
    condition     = output.waf_policy.policy_settings[0].enabled == true
    error_message = "Expected the dedicated WAF policy to be enabled."
  }

  assert {
    condition     = output.waf_policy.managed_rules[0].managed_rule_set[0].type == "Microsoft_DefaultRuleSet"
    error_message = "Expected Microsoft_DefaultRuleSet as the managed rule type."
  }

  assert {
    condition     = output.waf_policy.managed_rules[0].managed_rule_set[0].version == "2.1"
    error_message = "Expected DRS 2.1 as the managed rule set version."
  }

  assert {
    condition     = output.waf_policy.policy_settings[0].request_body_check == true
    error_message = "Expected request-body inspection to be enabled."
  }

  assert {
    condition     = output.waf_policy.policy_settings[0].max_request_body_size_in_kb == 128
    error_message = "Expected the default request-body size limit to be 128 KB."
  }

  assert {
    condition     = output.waf_policy.policy_settings[0].file_upload_limit_in_mb == 100
    error_message = "Expected the default file upload limit to be 100 MB."
  }

  assert {
    condition     = length(output.waf_policy.custom_rules) == 1
    error_message = "Expected a single synthetic rate-limit custom WAF rule."
  }

  assert {
    condition     = output.waf_policy.custom_rules[0].name == "SyntheticLoginRateLimit"
    error_message = "Expected the synthetic login rate-limit custom rule to exist."
  }

  assert {
    condition     = output.waf_policy.custom_rules[0].enabled == true
    error_message = "Expected the synthetic login rate-limit rule to be enabled."
  }

  assert {
    condition     = output.waf_policy.custom_rules[0].priority == 100
    error_message = "Expected the synthetic rate-limit rule to use priority 100."
  }

  assert {
    condition     = output.waf_policy.custom_rules[0].rule_type == "RateLimitRule"
    error_message = "Expected the synthetic rate-limit rule to use the RateLimitRule type."
  }

  assert {
    condition     = output.waf_policy.custom_rules[0].action == "Block"
    error_message = "Expected the synthetic rate-limit rule to block traffic."
  }

  assert {
    condition     = output.waf_policy.custom_rules[0].match_conditions[0].match_variables[0].variable_name == "RequestUri"
    error_message = "Expected the synthetic rate-limit rule to match on RequestUri."
  }

  assert {
    condition     = output.waf_policy.custom_rules[0].match_conditions[0].operator == "BeginsWith"
    error_message = "Expected the synthetic login path rule to use BeginsWith."
  }

  assert {
    condition     = length(output.waf_policy.custom_rules[0].match_conditions[0].match_values) == 1 && contains(output.waf_policy.custom_rules[0].match_conditions[0].match_values, "/api/login")
    error_message = "Expected the synthetic login path match value to contain exactly /api/login."
  }

  assert {
    condition     = output.waf_policy.custom_rules[0].rate_limit_threshold == 25
    error_message = "Expected the synthetic rate-limit rule threshold to be 25 requests."
  }

  assert {
    condition     = output.waf_policy.custom_rules[0].rate_limit_duration == "OneMin"
    error_message = "Expected the synthetic rate-limit rule duration to use the provider-supported OneMin value."
  }

  assert {
    condition     = output.waf_policy.custom_rules[0].group_rate_limit_by == "ClientAddr"
    error_message = "Expected the synthetic rate-limit rule to group per client address."
  }
}

run "detection_mode_policy" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synth-platform-dev/providers/Microsoft.Network/virtualNetworks/vnet-synth-app/subnets/AppGatewaySubnet"
    waf_mode            = "Detection"
    tls = {
      name     = "simulated-platform-cert"
      data     = base64encode("synthetic-platform-cert-data")
      password = "replace-with-synthetic-password"
    }
  }

  assert {
    condition     = azurerm_web_application_firewall_policy.platform.policy_settings[0].mode == "Detection"
    error_message = "Expected the WAF policy mode to be Detection when configured."
  }
}

run "waf_policy_wiring_regression" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synth-platform-dev/providers/Microsoft.Network/virtualNetworks/vnet-synth-app/subnets/AppGatewaySubnet"
    tls = {
      name     = "simulated-platform-cert"
      data     = base64encode("synthetic-platform-cert-data")
      password = "replace-with-synthetic-password"
    }
  }

  override_resource {
    target = azurerm_web_application_firewall_policy.platform
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synth-platform-dev/providers/Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies/waf-synth-platform-policy"
    }
    override_during = plan
  }

  assert {
    condition     = azurerm_application_gateway.platform.firewall_policy_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synth-platform-dev/providers/Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies/waf-synth-platform-policy"
    error_message = "Expected the Application Gateway to be wired to the dedicated synthetic WAF policy ID."
  }
}

run "rejects_invalid_waf_mode" {
  command = plan

  variables {
    resource_group_name = "rg-synth-platform-dev"
    subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-synth-platform-dev/providers/Microsoft.Network/virtualNetworks/vnet-synth-app/subnets/AppGatewaySubnet"
    waf_mode            = "Disabled"
    tls = {
      name     = "simulated-platform-cert"
      data     = base64encode("synthetic-platform-cert-data")
      password = "replace-with-synthetic-password"
    }
  }

  expect_failures = [var.waf_mode]
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
