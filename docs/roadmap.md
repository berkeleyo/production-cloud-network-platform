# Roadmap

## Current phase

The repository is now in the Phase 1 Terraform foundation and local validation phase. The project remains synthetic and non-deploying by design.

## Implemented

### Phase 1 — Foundation and guardrails
- Define the synthetic Azure hub-and-spoke reference model
- Model the dedicated AppGatewaySubnet and reserved firewall subnets
- Enforce explicit NSG and route defaults for workload traffic
- Keep the Application Gateway WAF_v2 and HTTPS-only model in scope
- Use mock_provider so Terraform tests remain offline and credential-free

### Phase 1 validation
- Add native terraform tests for route, subnet, and ingress checks
- Run validation with empty AZURE_CONFIG_DIR and throwaway HOME values
- Keep CI in place without referencing removed modules

## Planned

### Phase 2 — Firewall, policy, and service trust
- Implement the firewall/NVA resource itself as a planned future item
- Add WAF policy and DRS 2.1 only when intentionally introduced
- Extend backend TLS and service-to-service trust boundaries
- Add operational telemetry and broader management-segmentation controls

### Phase 3 — Portfolio polish
- Tighten narrative grounding and architecture documentation
- Keep the implementation aligned with the actual Terraform scope
