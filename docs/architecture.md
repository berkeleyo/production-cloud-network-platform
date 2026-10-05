# Architecture

## Current implementation

This repository models a synthetic Azure hub-and-spoke platform for offline Terraform validation and portfolio review. The design is intentionally narrow and is not a live Azure deployment.

## Decision summary

- App Gateway placement: public ingress is handled by a dedicated application gateway subnet that sits in the application spoke and keeps the gateway out of the workload tier.
- WAF boundary: the Application Gateway is fronted by a dedicated WAF policy in Prevention mode by default, with Detection supported for validation and tuning.
- Tier segmentation: workload traffic is separated into Web, API, and Data tiers with explicit trust paths: App Gateway -> Web on 443, Web -> API on 443, and API -> Data on 5432.
- Egress strategy: the workload default route is 0.0.0.0/0 -> VirtualAppliance at 10.10.0.4, which models a future hub firewall/NVA inspection path without deploying the actual resource.
- East-west routing: intra-application traffic is routed through Azure VNet-local paths while the security inspection hop is represented synthetically rather than enforced by a deployed firewall resource.
- TLS trust: backend HTTPS is modeled with a synthetic hostname, SNI alignment, and a trusted-root certificate object so the trust boundary is explicit without embedding live certificates or secrets.
- Offline status: every module is intentionally validated without Azure credentials, ARM_* values, or live apply actions.

## Address plan

- Hub VNet: 10.10.0.0/16
- Application spoke: 10.20.0.0/16
- Application tier subnets: 10.20.0.0/24, 10.20.10.0/24, 10.20.20.0/24
- Dedicated AppGatewaySubnet: 10.20.30.0/24
- AzureFirewallSubnet: 10.10.0.0/24 (reserved for the synthetic firewall/NVA path)

## Module boundaries

- Network module: VNet, subnets, NSGs, route tables, peering, and association logic
- Ingress module: public IP, WAF_v2 Application Gateway, WAF policy, backend HTTPS trust, and diagnostic settings
- Example composition: local dev reference for Terraform composition and validation
