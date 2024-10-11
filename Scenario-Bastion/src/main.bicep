param location string = resourceGroup().location

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: 'vnet-cps-testworkload-02'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      { 
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

resource bastion02 'Microsoft.Network/bastionHosts@2023-06-01' = {
  name: 'bast-testworkload-02'
  location: location
   properties: {
     ipConfigurations: [
       {
         name:'ipconfig'
          properties: {
            publicIPAddress: {
               id: bast02pip.id
            }
            subnet: {
               id: vnet.properties.subnets[0].id
            }
          }
       }
     ]
   }
}

 

resource bast02pip 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: 'pip-cps-testworkload02'
  location: location
   sku: {
     name: 'Standard'
   }
   properties: {
     publicIPAllocationMethod: 'Static'
   }
}
