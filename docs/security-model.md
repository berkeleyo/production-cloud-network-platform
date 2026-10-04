# Security model

## Current posture

The current repository models a deliberately narrow security posture for a synthetic Azure networking platform. The design uses explicit trust boundaries, restricted allow rules, and dedicated service-tag exceptions where the Azure platform requires them.

## Trust boundaries

- Internet to public Application Gateway ingress
- Application Gateway to private backend workloads
- Application spoke to hub services
- Hub egress inspection and control are planned; current hub subnets use Azure system/default Internet routing where applicable
- Stronger management-path separation is planned for Phase 2 and is not currently enforced

## Design principles

- No blanket allow rules for broad public sources
- The AppGatewaySubnet allows only required Azure service-tag and HTTPS edge traffic
- AzureFirewallSubnet is not attached to the general hub NSG or default route table
- Hub subnets currently rely on Azure's system/default Internet route where applicable; inspected or controlled hub egress is not implemented yet
- Stronger management-path separation is planned for Phase 2 rather than enforced in the current baseline

## Planned future controls

The firewall/NVA resource itself is not yet implemented. The route model represents the intended future inspection path and keeps the architecture honest about the remaining planned step. Management-path separation and tighter hub egress controls are planned for Phase 2 rather than currently enforced.

## Sensitive material

Certificate material in the example configuration is synthetic and treated as sensitive input. No real credentials or Azure authentication flows are used in this repository.
