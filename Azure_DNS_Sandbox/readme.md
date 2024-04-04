Lab environment for everything Azure DNS

Scenarios included:

Azure DNS Zone (Public)  
Azure Private DNS Zone - for a Storage Account Private Endpoint  
Azure Private DNS Zone - for registering the VMs in two VNETs  
Azure DNS Private Resolver - Inbound is configured, but none of the VNETs have it configured for use  
Azure DNS Private Resolver - Outbound is configured to send queries for contoso.com to DNS Servers "On Prem" (Azure VMs in a VPN connected VNET)

The link below can be used to quickly deploy the lab directly to your subscription.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fjimgodden%2FAzure_Networking_Labs%2Fmain%2FAzure_PrivateLink_Sandbox%2Fsrc%2Fmain.json)


Below is a diagram of the infrastructure

![Diagram of the infrastructure](diagram.drawio.png)

Note: This Diagram is in this repository, and can be modified via https://app.diagrams.net/
