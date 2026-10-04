# Network module

## Purpose

This module creates the synthetic Azure hub-and-spoke foundation used in the repository. It models VNet segmentation, explicit route tables, dedicated App Gateway handling, and secure-by-default NSG behavior without requiring live Azure access.

## Inputs

- resource_group_name: name of the synthetic resource group
- location: Azure region reference
- hub_name, application_spoke_name: logical VNet names
- hub_address_space, application_address_space: CIDR ranges
- hub_subnets, application_subnets: subnet definitions, including reserved subnet protection
- hub_nsg_rules, application_nsg_rules, app_gateway_nsg_rules: explicit NSG definitions
- hub_route_tables, application_route_tables: default route examples
- tags: synthetic metadata

## Outputs

- resource_group_name
- hub_vnet_id / hub_vnet_name
- application_vnet_id / application_vnet_name
- hub_subnet_ids / application_subnet_ids
- hub_subnet_nsg_associations / hub_subnet_route_associations
- application_subnet_nsg_associations / application_subnet_route_associations
- app_gateway_subnet_nsg_associations
- app_gateway_nsg_id
- application_default_route
- peering_ids

## Security and routing behavior

- Callers provide deliberate inbound allow rules for the ordinary hub and application NSGs.
- The module owns the final inbound deny baseline as `DenyAllInbound` at priority `4096` for those ordinary NSGs.
- Caller-supplied rules cannot remove or replace the module-owned deny baseline; they only add more allow entries above it.
- Inbound allow rules must stay below the module-owned deny priority; priority `4096` is reserved for the final deny baseline.
- Reserved subnet names are enforced internally and do not inherit general default NSG or route-table associations.
- The dedicated AppGatewaySubnet is associated only with the App Gateway-specific NSG.
- The application default route uses a VirtualAppliance next hop to the synthetic firewall/NVA path.
- Broad allow rules such as Internet, Any, or 0.0.0.0/0 are rejected for ordinary workload rules.

## Notes

- This module is reference-only and offline by design.
- The repository does not deploy Azure resources or authenticate to Azure.
- The firewall/NVA resource itself remains planned; the route model reflects that intended path only.
