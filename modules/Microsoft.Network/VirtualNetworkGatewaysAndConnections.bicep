param location_VirtualNetworkGateway1 string

param asn_VirtualNetworkGateway1 int

param name_VirtualNetworkGateway1 string

param subnetId_VirtualNetworkGateway1 string


param location_VirtualNetworkGateway2 string

param asn_VirtualNetworkGateway2 int

param name_VirtualNetworkGateway2 string

param subnetId_VirtualNetworkGateway2 string



param vpn_SharedKey string




module virtualNetworkGateway1 'VirtualNetworkGateway.bicep' = {
  name: 'virtualNetworkGateway1'
  params: {
    location: location_VirtualNetworkGateway1
    virtualNetworkGateway_ASN: asn_VirtualNetworkGateway1
    virtualNetworkGateway_Name: name_VirtualNetworkGateway1
    virtualNetworkGateway_Subnet_ResourceID: subnetId_VirtualNetworkGateway1
  }
}

module virtualNetworkGateway2 'VirtualNetworkGateway.bicep' = {
  name: 'virtualNetworkGateway2'
  params: {
    location: location_VirtualNetworkGateway2
    virtualNetworkGateway_ASN: asn_VirtualNetworkGateway2
    virtualNetworkGateway_Name: name_VirtualNetworkGateway2
    virtualNetworkGateway_Subnet_ResourceID: subnetId_VirtualNetworkGateway2
  }
}

module virtualNetworkGateway1_to_virtualNetworkGateway2_conn 'Connection_and_LocalNetworkGateway.bicep' = {
  name: 'virtualNetworkGateway1_to_virtualNetworkGateway2_conn'
  params: {
    location: location_VirtualNetworkGateway1
    virtualNetworkGateway_ID: virtualNetworkGateway1.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_ASN: virtualNetworkGateway2.outputs.virtualNetworkGateway_ASN
    vpn_Destination_BGPIPAddress: virtualNetworkGateway2.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_Name: virtualNetworkGateway2.outputs.virtualNetworkGateway_Name
    vpn_Destination_PublicIPAddress: virtualNetworkGateway2.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
  }
}

module virtualNetworkGateway2_to_virtualNetworkGateway1_conn 'Connection_and_LocalNetworkGateway.bicep' = {
  name: 'virtualNetworkGateway2_to_virtualNetworkGateway1_conn'
  params: {
    location: location_VirtualNetworkGateway2
    virtualNetworkGateway_ID: virtualNetworkGateway2.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_ASN: virtualNetworkGateway1.outputs.virtualNetworkGateway_ASN
    vpn_Destination_BGPIPAddress: virtualNetworkGateway1.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_Name: virtualNetworkGateway1.outputs.virtualNetworkGateway_Name
    vpn_Destination_PublicIPAddress: virtualNetworkGateway1.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
  }
}
