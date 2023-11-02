@description('Azure Datacenter location that the main resouces will be deployed to.')
param location string

@description('Name of the Virtual Network.')
param vnet_Name string = 'OnPrem_VNET'

@description('Address Prefix of the Virtual Network.')
param vnet_AddressPrefix string = '10.210.0.0/16'

@description('Deploys a Az FW if true')
param usingAzFW bool

@description('Name of the Azure Firewall')
param AzFW_Name string = 'OnPrem_AzFW'

@description('Sku name of the Azure Firewall.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param AzFW_SKU string = 'Basic'

@description('Name of the Azure Firewall Policy')
param AzFWPolicy_Name string = 'OnPrem_AzFW_Policy'

@description('Name of the Azure Virtual Network Gateway')
param OnPrem_VNG_Name string = 'OnPrem_VNG'

@description('OnPrem VPN ASN')
param OnPrem_VNG_ASN int = 65200

@description('Azure Bastion Name')
param Bastion_Name string = 'OnPrem_Bastion'

@description('Name of the Azure Bastion Public IP Address')
param Bastion_PIP_Name string = 'OnPrem_Bastion_PIP'

@description('Name of the Azure Virtual Network Gateway Subnet')
param subnet_Gateway_Name string = 'GatewaySubnet'

@description('Address Prefix of the Azure Virtual Network Gateway Subnet')
param subnet_Gateway_AddressPrefix string = '10.210.0.0/24'

@description('Name of the Azure Firewall Subnet')
param subnet_AzFW_Name string = 'AzureFirewallSubnet'

@description('Address Prefix of the Azure Firewall Subnet')
param subnet_AzFW_AddressPrefix string = '10.210.1.0/24'

@description('Name of the Azure Firewall Management Subnet')
param subnet_AzFW_Management_Name string = 'AzureFirewallManagementSubnet'

@description('Address Prefix of the Azure Firewall Management Subnet')
param subnet_AzFW_Management_AddressPrefix string = '10.210.2.0/24'

@description('Name of the Azure Bastion Subnet')
param subnet_Bastion_Name string = 'AzureBastionSubnet'

@description('Address Prefix of the Azure Bastion Subnet')
param subnet_Bastion_AddressPrefix string = '10.210.3.0/24'

@description('Name of the General Subnet for any other resources')
param subnet_General_Name string = 'General'

@description('Address Prefix of the General Subnet')
param subnet_General_AddressPrefix string = '10.210.4.0/24'

@description('Name of the Network Security Group')
param defaultNSG_Name string = 'OnPrem_NSG'

@description('Name of the Route Table')
param routeTable_Name string = 'OnPrem_RouteTable'

@description('Name of the Virtual Machine')
param vm_Name string = 'OnPrem-VM'

@description('Name of the Virtual Machines Network Interface')
param nic_Name string = '${vm_Name}_nic1'

@description('Admin Username for the Virtual Machine')
param vm_AdminUserName string

@description('Password for the Virtual Machine Admin User')
@secure()
param vm_AdminPassword string

module vnetHub 'Networking/VirtualNetworkHub.bicep' = {
  name: 'OnPrem_VNET'
  params: {
    defaultNSG_Name: defaultNSG_Name
    routeTable_Name: routeTable_Name
    location: location
    subnet_AzFW_Name: subnet_AzFW_Name
    subnet_AzFW_AddressPrefix: subnet_AzFW_AddressPrefix
    subnet_AzFW_Management_Name: subnet_AzFW_Management_Name
    subnet_AzFW_Management_AddressPrefix: subnet_AzFW_Management_AddressPrefix
    subnet_Bastion_Name: subnet_Bastion_Name
    subnet_Bastion_AddressPrefix: subnet_Bastion_AddressPrefix
    subnet_Gateway_Name: subnet_Gateway_Name
    subnet_Gateway_AddressPrefix: subnet_Gateway_AddressPrefix
    subnet_General_Name: subnet_General_Name
    subnet_General_AddressPrefix: subnet_General_AddressPrefix
    vnet_AddressPrefix: vnet_AddressPrefix
    vnet_Name: vnet_Name
  }
}

module firewall 'Networking/AzureFirewall.bicep' =  if (usingAzFW) {
  name: 'OnPrem_AzFW'
  params: {
    AzFW_Name: AzFW_Name
    AzFW_SKU: AzFW_SKU
    AzFWPolicy_Name: AzFWPolicy_Name
    azfwSubnetID: vnetHub.outputs.azfwSubnetID
    azfwManagementSubnetID: vnetHub.outputs.azfwManagementSubnetID
    location: location
  }
  // Azure Firewall fails to deploy if the Azure Virtual Network Gateway is still deploying
  dependsOn: [
    vpn
  ]
}

module vpn 'Networking/VPN.bicep' = {
  name: 'OnPrem_VPN'
  params: {
    location: location
    OnPrem_VNG_Name: OnPrem_VNG_Name
    OnPrem_VNG_ASN: OnPrem_VNG_ASN
    OnPrem_VNG_Subnet_ResourceID: vnetHub.outputs.gatewaySubnetID
  }
}

module bastion 'Networking/Bastion.bicep' = {
  name: 'OnPrem_Bastion'
  params: {
    bastion_name: Bastion_Name
    bastion_vip_name: Bastion_PIP_Name
    bastionSubnetID: vnetHub.outputs.bastionSubnetID
    location: location
  }
}

module vm '../Compute/NetTestVM.bicep' = {
  name: 'OnPrem_NetTestVM'
  params: {
    location: location
    nic_Name: nic_Name
    subnetID: vnetHub.outputs.generalSubnetID
    vm_AdminPassword: vm_AdminPassword
    vm_AdminUserName: vm_AdminUserName
    vm_Name: vm_Name
  }
}

output onPremVNGResourceID string = vpn.outputs.onpremVNGResourceID
output onpremVNGName string = vpn.outputs.onpremVNGName
output onpremVNGPIP string = vpn.outputs.onpremVNGPIP
output onPremVNGBGPAddress string = vpn.outputs.onPremVNGBGPAddress
output onpremVNGASN int = vpn.outputs.onpremVNGASN


