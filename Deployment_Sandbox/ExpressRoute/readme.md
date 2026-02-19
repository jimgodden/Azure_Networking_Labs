# ExpressRoute Sandbox Lab

This lab deploys an ExpressRoute environment with simulated "On-Premises" and Azure connectivity, using a centralized Bastion for secure VM access via VNet peering.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           ExpressRoute Lab Architecture                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   "OnPrem" Environment (10.100.0.0/16)     Azure Environment (10.0.0.0/16)      │
│   ┌───────────────────────────────┐        ┌───────────────────────────────┐    │
│   │         OnPrem_VNet           │        │          Azure_VNet           │    │
│   │                               │        │                               │    │
│   │  ┌─────────────────────────┐  │        │  ┌─────────────────────────┐  │    │
│   │  │    General Subnet       │  │        │  │    General Subnet       │  │    │
│   │  │    10.100.0.0/24        │  │        │  │    10.0.0.0/24          │  │    │
│   │  │   ┌─────────────────┐   │  │        │  │   ┌─────────────────┐   │  │    │
│   │  │   │   OnPrem-VM     │   │  │        │  │   │    Azure-VM     │   │  │    │
│   │  │   │  Win Srv 2025   │   │  │        │  │   │  Win Srv 2025   │   │  │    │
│   │  │   └─────────────────┘   │  │        │  │   └─────────────────┘   │  │    │
│   │  └─────────────────────────┘  │        │  └─────────────────────────┘  │    │
│   │                               │        │                               │    │
│   │  ┌─────────────────────────┐  │        │  ┌─────────────────────────┐  │    │
│   │  │   GatewaySubnet         │  │        │  │   GatewaySubnet         │  │    │
│   │  │   10.100.1.0/24         │  │        │  │   10.0.1.0/24           │  │    │
│   │  │   ┌─────────────────┐   │  │        │  │   ┌─────────────────┐   │  │    │
│   │  │   │ OnPrem_ExR_GW   │   │  │        │  │   │  Azure_ExR_GW   │   │  │    │
│   │  │   └────────┬────────┘   │  │        │  │   └────────┬────────┘   │  │    │
│   │  └────────────┼────────────┘  │        │  └────────────┼────────────┘  │    │
│   └───────────────┼───────────────┘        └───────────────┼───────────────┘    │
│         │         │                                        │         │          │
│         │         │       ┌─────────────────────┐          │         │          │
│         │         │       │  ExpressRoute       │          │         │          │
│         │         └───────┤     Circuit         ├──────────┘         │          │
│         │                 │  (50 Mbps)          │                    │          │
│         │                 └─────────────────────┘                    │          │
│         │                                                            │          │
│         │    VNet Peering                             VNet Peering   │          │
│         │         │                                        │         │          │
│         │         │   ┌────────────────────────────┐       │         │          │
│         │         │   │  Bastion VNet (10.250.0.0) │       │         │          │
│         │         │   │  ┌──────────────────────┐  │       │         │          │
│         └─────────┼───┤  │ Centralized_Bastion  │  ├───────┼─────────┘          │
│                   │   │  │   (Standard SKU)     │  │       │                    │
│                   │   │  └──────────────────────┘  │       │                    │
│                   │   └────────────────────────────┘       │                    │
│                   │                                        │                    │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Resources Deployed

### "On-Premises" Environment
- **OnPrem_VNet** (10.100.0.0/16) - Virtual Network simulating on-premises
- **OnPrem-VM** - Windows Server 2025 Azure Edition
- **OnPrem_ExR_Gateway** - ExpressRoute Gateway

### Azure Environment
- **Azure_VNet** (10.0.0.0/16) - Virtual Network in Azure
- **Azure-VM** - Windows Server 2025 Azure Edition
- **Azure_ExR_Gateway** - ExpressRoute Gateway

### Shared Resources
- **ExR_Circuit** - ExpressRoute Circuit connecting both environments
- **Centralized_Bastion** - Single Bastion with VNet peering to both environments
- **Centralized_Bastion_vnet** (10.250.0.0/24) - Dedicated VNet for Bastion

## Important Notes

⚠️ **ExpressRoute Circuit Provisioning**: In a real-world scenario, the ExpressRoute circuit would need to be provisioned through a service provider (like Megaport, Equinix, etc.). This lab creates the Azure-side resources, but full connectivity requires:

1. Contact your service provider to provision the circuit using the **Service Key** output
2. Wait for the provider to complete provisioning (status changes from "NotProvisioned" to "Provisioned")
3. The connections will then become active

## Deployment

```powershell
# From the repository root
.\Deployment_Sandbox\ExpressRoute\deployment.ps1
```

## Testing Connectivity

Once the ExpressRoute circuit is provisioned:

1. Connect to **OnPrem-VM** via Bastion
2. Ping **Azure-VM** using its private IP (10.0.0.x)
3. Verify routes are learned via ExpressRoute

```powershell
# From OnPrem-VM
Test-NetConnection -ComputerName <Azure-VM-PrivateIP> -Port 3389
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| OnPremLocation | eastus2 | Location for "On-Premises" resources |
| AzureLocation | eastus2 | Location for Azure resources |
| virtualMachine_Size | Standard_D2_v5 | VM size for both VMs |
| expressRouteGateway_SKU | Standard | SKU for ExpressRoute Gateways |
| expressRouteCircuit_BandwidthInMbps | 50 | Circuit bandwidth |

## Cost Considerations

ExpressRoute resources can be expensive:
- ExpressRoute Gateways incur hourly charges
- ExpressRoute Circuits have metered or unlimited pricing
- Consider deleting resources after testing

## Clean Up

Delete the resource group to remove all resources:

```powershell
Remove-AzResourceGroup -Name "Sandbox-ExpressRoute-RG" -Force
```
