# Architecture

## Current implementation

This repository models a synthetic Azure hub-and-spoke platform for offline Terraform validation and portfolio review. It is not a live Azure deployment and does not provision a production firewall/NVA resource.

## Network topology

- A public Application Gateway provides the HTTPS ingress boundary.
- The Application Gateway is placed in a dedicated `AppGatewaySubnet` inside the application VNet.
- The application spoke is segmented into Web, API and Data subnets.
- A hub VNet contains reserved firewall, shared-services, management and gateway subnets.
- Hub/application VNets are represented with bidirectional peering.
- NSGs and route tables are modeled as Terraform resources and associations.

## Trust boundaries

- Internet → public Application Gateway
- Application Gateway → Web tier on HTTPS 443
- Web tier → API tier on HTTPS 443
- API tier → Data tier on PostgreSQL 5432
- Application spoke → reserved NVA inspection boundary on the synthetic default route

## Implemented controls

- Dedicated WAF_v2 Application Gateway policy
- TLS listener and HTTPS backend settings
- Module-owned `DenyAllInbound` baseline in tier NSGs
- Explicit caller allow rules
- Reserved subnet protection
- Dedicated App Gateway NSG
- VNet peering
- Synthetic route-table default toward `10.10.0.4`
- Native Terraform module tests with the mock provider

## Planned components

The following remain architectural intent only:

- Azure Firewall or NVA deployment
- Live east-west inspection enforcement
- Real monitoring/workspace integration
- Production certificate provisioning
- Real public DNS and application endpoints
- Remote backend/state management

## Module boundaries

- `terraform/modules/network` owns VNets, subnets, NSGs, route tables and peering.
- `terraform/modules/ingress` owns public IP, Application Gateway, WAF policy and diagnostic settings.
- `terraform/examples/dev` demonstrates module composition.

## Operational assumptions

- The repository does not authenticate to Azure.
- Terraform tests use `mock_provider` and isolated Azure configuration directories.
- No `terraform apply` workflow is included.
- The CIDRs are legitimate private-network architecture examples, not real infrastructure addresses.
- State is local-only unless a consumer supplies a controlled backend externally.

## Trade-offs

The repository deliberately trades live Azure fidelity for deterministic review and offline validation. This makes the repository useful for architecture, module design and policy testing, but it does not prove live Azure behavior or operational readiness.
