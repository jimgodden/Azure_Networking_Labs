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
> The example below assumes you are deploying 1 source and 1 destination Linux VM.
> The first VM in dstSubnet will get IP `10.0.1.4`.

### Basic Usage (60 second test)

```bicep
// Destination VM runs iperf3 server (runs indefinitely)
param destinationLinuxVMScriptFile = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/iperf3-server.sh'
param destinationLinuxVMScriptCommand = 'nohup bash iperf3-server.sh > /dev/null 2>&1 &'

// Source VM runs iperf3 client (waits 5 min for server, then runs 60 sec test)
param sourceLinuxVMScriptFile = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/iperf3-client.sh'
param sourceLinuxVMScriptCommand = 'nohup bash iperf3-client.sh 10.0.1.4 > /dev/null 2>&1 &'
```

### Script Parameters

**iperf3-client.sh**: `<server-ip> [duration] [parallel-streams] [port]`

| Parameter | Default | Description |
|-----------|---------|-------------|
| server-ip | (required) | IP address of the iperf3 server |
| duration | 60 | Test duration in seconds. Use `0` for infinite |
| parallel-streams | 8 | Number of parallel TCP streams |
| port | 5201 | Server port |

**iperf3-server.sh**: `[port]`

| Parameter | Default | Description |
|-----------|---------|-------------|
| port | 5201 | Port to listen on |

### Examples

**2 minute test:**
```bash
bash iperf3-client.sh 10.0.1.4 120
```

**Infinite test (Ctrl+C to stop):**
```bash
bash iperf3-client.sh 10.0.1.4 0
```

**16 parallel streams for higher throughput:**
```bash
bash iperf3-client.sh 10.0.1.4 60 16
```

**Custom port:**
```bash
bash iperf3-server.sh 5555
bash iperf3-client.sh 10.0.1.4 60 8 5555
```

### Manual Testing via Bastion

After deployment, connect to the VMs via Bastion and run manually:

```bash
# On destination VM (10.0.1.4)
bash iperf3-server.sh

# On source VM (10.0.0.4)
bash iperf3-client.sh 10.0.1.4 60
```

