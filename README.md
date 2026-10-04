# production-cloud-network-platform

Synthetic Azure networking reference built as a portfolio-grade Terraform foundation. This repository models a hub-and-spoke design, a dedicated App Gateway subnet, and a planned future firewall/NVA inspection path without deploying any live Azure resources.

## Current status

Terraform foundation implemented and locally validated, not deployed.

## Architecture summary

- Hub VNet: 10.10.0.0/16
- Application spoke: 10.20.0.0/16
- Dedicated AppGatewaySubnet: 10.20.30.0/24
- WebSubnet: 10.20.0.0/24
- ApiSubnet: 10.20.10.0/24
- DataSubnet: 10.20.20.0/24
- Trust model: App Gateway -> Web : 443, Web -> API : 443, API -> Data : 5432
- Each tier has its own NSG plus a final module-owned DenyAllInbound at priority 4096
- Application workload default route: 0.0.0.0/0 -> VirtualAppliance at 10.10.0.4
- AzureFirewallSubnet is reserved and not associated with the general hub NSG or default route table
- East-west firewall inspection is planned rather than currently enforced

## Local validation status

Validated locally without Azure authentication or deployment:

- Terraform format check successful
- terraform init -backend=false successful for the network module, ingress module, and dev example
- terraform validate successful for the final local configuration
- terraform test successful with offline Azure config isolation and no Azure CLI credentials used

## Project disclaimer

This project is independently designed for portfolio use and is not a live Azure deployment, an approved production topology, or a customer environment. All values are synthetic and intended for architecture review and Terraform validation only.

## Roadmap

See [docs/roadmap.md](docs/roadmap.md) for the implementation phases reflected in this repository.
