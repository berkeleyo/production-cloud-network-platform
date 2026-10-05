# Ingress module

## Purpose

This module defines the synthetic public ingress layer for the project. It models an Azure Application Gateway v2 front door with WAF enabled, an HTTPS-only public listener, and a private backend pool.

## Inputs

- name: logical Application Gateway name
- resource_group_name: resource group for the gateway
- location: Azure region reference
- subnet_id: subnet ID for the dedicated AppGatewaySubnet
- backend_pool_addresses: backend private IPs
- backend_port: backend HTTPS port
- backend_host: synthetic health probe host
- health_path: health endpoint path
- frontend_port: must be 443 for this Phase 1 model
- tls: sensitive certificate object with name, data, and password
- tags: synthetic metadata
- waf_enabled: must remain true
- waf_mode: Detection or Prevention

## Outputs

- application_gateway_id
- application_gateway_name
- application_gateway_sku
- public_ip_address
- backend_pool_name
- listener_name
- waf_enabled
- ssl_policy_name
- application_gateway_waf_enabled

## Security and TLS behavior

- The public frontend is HTTPS-only.
- The gateway uses the supported predefined AppGwSslPolicy20220101 policy.
- The TLS model is intentionally simple and does not include a custom minimum-protocol variable alongside a predefined policy.
- No default real certificate material is embedded in the repo.
- The certificate object is sensitive and must be supplied explicitly.

## Notes

- This module is reference-only and offline; no live Azure deployment has occurred.
- The Terraform configuration contains a dedicated Application Gateway WAF policy with Microsoft Default Rule Set 2.1 enabled.
- The default WAF mode is Prevention, and the synthetic login endpoint is represented by a request path rate-limit example for /api/login.
- The design intentionally keeps the model synthetic and does not claim live attack blocking or production telemetry.
- Backend TLS remains outside the current scope and is not treated as a fully implemented service-to-service trust boundary yet.
