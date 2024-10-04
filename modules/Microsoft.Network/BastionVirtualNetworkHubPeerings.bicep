param bastion_VirtualNetwork_Id string

param other_VirtualNetwork_Ids array

module bastion_to_other_VirtualNetwork_Peerings 'VirtualNetworkPeeringSpoke2SpokeUsingIds.bicep' = [ for other_VirtualNetwork_Id in other_VirtualNetwork_Ids: {
  name: 'bastion_to_${split(other_VirtualNetwork_Id, '/')[8]}' // The Split() ultimately gets the name of the VNET from the Resource Id
  params: {
    virtualNetwork1_Id: bastion_VirtualNetwork_Id
    virtualNetwork2_Id: other_VirtualNetwork_Id
  }
}]


// module bastion_to_other_VirtualNetwork_Peerings 'VirtualNetworkPeeringSpoke2Spoke.bicep' = [ for i in range(0, length(other_VirtualNetwork_Ids)): {
//   // name: 'bastion_to_other_VirtualNetwork_Peering${i}'
//   name: 'bastion_to_${split(other_VirtualNetwork_Ids[i], '/')[8]}' // The Split() ultimately gets the name of the VNET from the Resource Id
//   params: {
//     virtualNetwork1_Name: bastion_VirtualNetwork_Id
//     virtualNetwork2_Name: other_VirtualNetwork_Ids[i]
//   }
// }]
