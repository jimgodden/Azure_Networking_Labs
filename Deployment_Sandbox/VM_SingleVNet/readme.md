# VM Single VNet Lab

Deploys source and destination VMs in a **single VNet** for testing VM-to-VM connectivity without VNet peering costs.

## Deployment

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fjimgodden%2FAzure_Networking_Labs%2Fmain%2FDeployment_Sandbox%2FVM_SingleVNet%2Fsrc%2Fmain.json)

## Cost Benefit

Traffic between subnets within the same VNet is **FREE** - no peering charges apply!

## Architecture

```
+--------------------------------------------------+
|                    VNet (10.0.0.0/16)            |
|                                                  |
|  +------------+              +------------+      |
|  | srcSubnet  |              | dstSubnet  |      |
|  | 10.0.0.0/24|              | 10.0.1.0/24|      |
|  |  Source VMs|              |  Dest VMs  |      |
|  +-----+------+              +------+-----+      |
|        |                            |            |
|        +---------- NAT GW ----------+            |
|                                                  |
|  +------------------------+                      |
|  | AzureFirewallSubnet    | (optional)           |
|  | 10.0.100.0/26          |                      |
|  +------------------------+                      |
+--------------------------------------------------+
            |
        Bastion (10.200.0.0/16)
```

## Subnets

| Subnet | Address Range | Purpose |
|--------|---------------|---------|
| srcSubnet | 10.0.0.0/24 | Source VMs |
| dstSubnet | 10.0.1.0/24 | Destination VMs |
| AzureFirewallSubnet | 10.0.100.0/26 | Azure Firewall (optional) |
| AzureFirewallManagementSubnet | 10.0.100.64/26 | Firewall Management (Basic SKU) |

## Key Features

- **NAT Gateway**: Provides consistent outbound IP for all VMs
- **Bastion**: Secure RDP/SSH access without public IPs on VMs
- **Custom Scripts**: Run configuration scripts on VMs at deployment
- **Flexible VM Count**: Deploy 0-99 Windows or Linux VMs per subnet

## Example: iperf3 Testing on Linux VMs

> [!NOTE]
> Only use this if you are deploying 1 source and 1 destination Linux VM

```bicep
// Destination VM runs iperf3 server
// Source VM runs iperf3 client (with delay to wait for server)
param sourceLinuxVMScriptFile = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/refs/heads/main/scripts/iperf3-client.sh'
param sourceLinuxVMScriptCommand = 'nohup bash iperf3-client.sh 10.0.1.4 > /dev/null 2>&1 &'

param destinationLinuxVMScriptFile = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/refs/heads/main/scripts/iperf3-server.sh'
param destinationLinuxVMScriptCommand = 'nohup bash iperf3-server.sh > /dev/null 2>&1 &'
```

