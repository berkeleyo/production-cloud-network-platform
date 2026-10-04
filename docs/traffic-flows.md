# Traffic flows

These examples describe the reference behaviour of the synthetic Azure networking design. They are for architecture review and Terraform validation only; this repository does not connect to Azure or deploy infrastructure.

## 1. Public HTTPS request

1. A user requests https://app.example.com.
2. Traffic reaches the public Application Gateway frontend.
3. WAF_v2 inspects the request and the HTTPS listener terminates TLS.
4. The gateway forwards the request to the backend pool in the application spoke.

## 2. Tier trust model

1. App Gateway -> Web on TCP 443.
2. Web -> API on TCP 443.
3. API -> Data on TCP 5432.
4. Each tier uses its own NSG and ends with a module-owned DenyAllInbound rule at priority 4096.
5. The design keeps these rules explicit and does not claim real packet forwarding is simulated by Terraform.

## 3. Application spoke egress

1. Workloads send outbound traffic toward the future inspection path.
2. The application default route uses VirtualAppliance with a synthetic next-hop IP.
3. The design keeps the egress path explicit instead of broad default-to-internet routing.
4. Intra-VNet east-west traffic follows Azure VNet-local routing; firewall/NVA inspection is planned rather than implemented.

## 4. Azure service-tag exceptions

The dedicated AppGatewaySubnet allows required Azure platform traffic, including GatewayManager and AzureLoadBalancer traffic, plus public HTTPS ingress from the intended edge source.

## 5. Reserved subnet intent

The AzureFirewallSubnet is reserved for a future firewall or NVA and is intentionally not associated with the general hub NSG or default route table.
