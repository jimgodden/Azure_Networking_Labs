# Azure Firewall with Connection Monitor

## Overview

This sandbox deploys an Azure Firewall (Basic SKU) between a source and destination Windows Server 2025 VM, both running IIS with HTTPS support. Network Watcher Connection Monitor sends TCP 3389 and HTTPS 443 probes through the firewall from source to destination.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  VNet: 10.0.0.0/16                                               │
│                                                                   │
│  ┌─────────────────┐    ┌──────────────────┐    ┌──────────────┐ │
│  │ General Subnet   │    │ AzureFirewall    │    │ PE Subnet    │ │
│  │ 10.0.0.0/24      │───▶│ Subnet           │───▶│ 10.0.1.0/24  │ │
│  │                  │    │ 10.0.6.0/24      │    │              │ │
│  │  sourceVM (IIS)  │    │  Azure Firewall  │    │ destVM (IIS) │ │
│  └─────────────────┘    │  (Basic SKU)     │    └──────────────┘ │
│                          └──────────────────┘                     │
│  ┌─────────────────┐                                              │
│  │ AzureBastionSub  │                                             │
│  │ 10.0.8.0/24      │                                             │
│  │  Bastion (Basic) │                                             │
│  └─────────────────┘                                              │
└──────────────────────────────────────────────────────────────────┘
```

## Azure Firewall Rules

| Rule Type | Name | Protocol | Port | Source | Destination |
|-----------|------|----------|------|--------|-------------|
| Network Rule | Allow_TCP_3389 | TCP | 3389 | 10.0.0.0/24 | 10.0.1.0/24 |
| Application Rule | Allow_HTTPS_443 | HTTPS | 443 | 10.0.0.0/24 | * |

## Connection Monitor Tests

| Test Name | Protocol | Port | Source | Destination |
|-----------|----------|------|--------|-------------|
| TCP_3389 | TCP | 3389 | sourceVM | destinationVM |
| HTTPS_443 | HTTPS | 443 | sourceVM | destinationVM |

## Resources Deployed

- Virtual Network with subnets (General, PrivateEndpoints, AzureFirewall, AzureFirewallManagement, AzureBastion)
- Source Windows Server 2025 VM with IIS + HTTPS (General subnet)
- Destination Windows Server 2025 VM with IIS + HTTPS (PrivateEndpoints subnet)
- Azure Firewall (Basic SKU) with network and application rules
- Azure Bastion (Basic SKU)
- Network Watcher Connection Monitor
- Network Watcher Flow Logs
- Log Analytics Workspace
- Storage Account (for flow logs)
- UDRs routing inter-subnet traffic through the firewall

## Deployment

```powershell
.\Tools\deployment.ps1 -DeploymentName "Sandbox-AzFW_ConnectionMonitor" -Location "eastus2"
```
