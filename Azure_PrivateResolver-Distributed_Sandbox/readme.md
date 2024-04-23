# Lab environment for most Azure DNS scenarios

## Deployment

The link below can be used to quickly deploy the lab directly to your subscription.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fjimgodden%2FAzure_Networking_Labs%2F%2FAzure_PrivateResolver-Distributed_Sandbox%2Fsrc%2Fmain.json)

## Scenarios

Azure DNS Zone (Public) - non delegated  
Azure Private DNS Zone - for a Storage Account Private Endpoint  
Azure Private DNS Zone - for registering the VMs in two VNETs  
Azure DNS Private Resolver - [Centralized DNS Architecture](https://learn.microsoft.com/en-us/azure/dns/private-resolver-architecture#centralized-dns-architecture)

## Azure DNS Zone (Public) - non delegated

### Resources
- DNS Zone

Creates a DNS Zone with the following name: 'DNSSandboxTest${uniqueString(resourceGroup().id)}.com'  
Note: ${uniqueString(resourceGroup().id)} will be a randomly generated string based on the Resource Group name.  

You will not be able to resolve this DNS Zone via the usual public DNS Servers like 1.1.1.1 since the DNS Zone is not delegated from a DNS provider such as GoDaddy or CloudFlare.  Instead, you can resolve the DNS Zone by specifying one of the Name Servers listed in the DNS Zone's Portal page.   

Below is an example of resolving the DNS Zone via one of the default provided Name Servers.

DNS Zone: AzureNetworkTest.com  

Name server 1: ns1-37.azure-dns.com.  
Name server 2: ns2-37.azure-dns.net.  
Name server 3: ns3-37.azure-dns.org.  
Name server 4: ns4-37.azure-dns.info.  

### PowerShell
```
PS C:\> Resolve-DNSName -Name AzureNetworkTest.com -Server ns1-37.azure-dns.com.

Name                        Type TTL   Section    PrimaryServer               NameAdministrator           SerialNumber
----                        ---- ---   -------    -------------               -----------------           ------------
AzureNetworkTest.com        SOA  300   Authority  ns1-37.azure-dns.com        azuredns-hostmaster.microso 1
```

## Azure Private DNS Zone - for a Storage Account Private Endpoint 

### Resources
- Private DNS Zone
  - Name: privatelink.blob.windows.core.net
- Storage Account
  - Name: storagedns(randomString)
- Private Endpoint - Blob
  - Name: Hub_storagedns(randomString)_blob_pe
  - IP Address: 

### Explanation

Creates a Private DNS Zone and links it to a Private Endpoint which can be used to access a Storage Account.




## Virtual Machines

All Virtual Machines are running Windows Server 2022 with the following installed via Chocolatey:  

 - Wireshark
 - PowerShell Core
 - Windows Terminal
 - Visual Studio Code
 - Python3

Hub and Spoke Virtual Machines can be accessed via Bastion.

OnPrem-WinDns0 and OnPrem-WinDns1 are running as DNS Servers.  
They are hosting zone "contoso.com." with an A Record of "a" that resolves to 172.16.0.1  

Hub-WinDns0 and Hub-WinDns1 are running as DNS Servers.  
They are forwarding all queries received to 168.63.129.16

Spoke-WinIis is running as a Web Server.
The Website can be reached at https://spoke-winiis.azure-contoso.com from either the Hub DNS Virtual Machines.  
Note: The domain name will change if you alter the parameter "privateDNSZone_Name".

## Infrastructure

Diagram of the infrastructure

![Diagram of the infrastructure](diagram.drawio.png)
