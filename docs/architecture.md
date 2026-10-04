# Architecture

## Current implementation

This repository models a synthetic Azure hub-and-spoke network for local Terraform validation and portfolio review. The design is deliberately narrow in scope and does not represent a live Azure deployment.

## Address plan

- Hub VNet: 10.10.0.0/16
- Application spoke: 10.20.0.0/16
- Application tier subnets: 10.20.0.0/24, 10.20.10.0/24, 10.20.20.0/24
- Dedicated AppGatewaySubnet: 10.20.30.0/24
- AzureFirewallSubnet: 10.10.0.0/24 (reserved for a future firewall/NVA resource)

## Ingress and application design

- Public HTTPS enters through the Application Gateway frontend on port 443.
- The gateway uses WAF_v2 with autoscale minimum capacity 2.
- The gateway sits in a dedicated AppGatewaySubnet and does not host backend workload addresses.
- The backend pool uses private application addresses in the workload subnets.

## Routing and egress

- The application spoke default route points to a future hub firewall/NVA using VirtualAppliance.
- The route is represented as 0.0.0.0/0 -> 10.10.0.4, which is a synthetic next hop and not a deployed resource.
- The AzureFirewallSubnet is intentionally excluded from the general hub NSG and default route-table association.
- There is no general hub-wide default-to-Internet route in the current implementation.

## Planned future item

The firewall/NVA resource itself is planned and not yet implemented. The route model reflects the intended inspection path only.

## Module boundaries

- Network module: VNet, subnets, NSGs, route tables, peering, and association logic
- Ingress module: public IP, WAF_v2 Application Gateway, frontend TLS policy, and health probing
- Example composition: local dev reference for Terraform composition and validation
