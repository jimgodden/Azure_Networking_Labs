@description('Azure Datacenter location for the source resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
var virtualMachine_Size = 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
var acceleratedNetworking = false

var tagValues = { Training: 'BGPLab' }

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: 'virtualNetwork'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.100.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.100.0.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'Subnet01'
        properties: {
          addressPrefix: '10.100.1.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          networkSecurityGroup: {
            id: genericNSG.id
          }
        }
      }
      {
        name: 'Subnet02'
        properties: {
          addressPrefix: '10.100.2.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled' 
          networkSecurityGroup: {
            id: genericNSG.id
          }
        }
      }
      {
        name: 'Subnet03'
        properties: {
          addressPrefix: '10.100.3.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled' 
          networkSecurityGroup: {
            id: genericNSG.id
          }
        }
      }
      {
        name: 'Subnet04'
        properties: {
          addressPrefix: '10.100.4.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          networkSecurityGroup: {
            id: genericNSG.id
          }
        }
      }
    ]
    enableDdosProtection: false
  }
  tags: tagValues
}

resource genericNSG 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'genericNSG'
  location: location
}

module networkInterface '../../../modules/Microsoft.Network/NetworkInterface.bicep' = [ for i in range(1, 4):  {
  name: 'VM0${i}_networkInterface'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    networkInterface_Name: 'VM0${i}_networkInterface'
    subnet_ID: virtualNetwork.properties.subnets[i].id
    privateIPAddress: '10.100.${i}.${i}0'
    privateIPAllocationMethod: 'Static'
    tagValues: tagValues
  }
} ]

resource virtualMachine_Linux 'Microsoft.Compute/virtualMachines@2023-03-01' = [ for i in range(1, 4):  {
  name: 'VM0${i}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: virtualMachine_Size
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        osType: 'Linux'
        name: 'VM0${i}_OsDisk_1'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        deleteOption: 'Delete'
      }
      dataDisks: []
    }
    osProfile: {
      computerName: 'VM0${i}'
      adminUsername: virtualMachine_AdminUsername
      adminPassword: virtualMachine_AdminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'ImageDefault'
          assessmentMode: 'ImageDefault'
        }
      }
      secrets: []
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface[i - 1].outputs.networkInterface_ID
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
  tags: tagValues
} ]

resource vm_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = [ for i in range(1, 4):  {
  parent: virtualMachine_Linux[i - 1]
  name: 'installcustomscript'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/FRR_BGP_Training_Configuration.sh'
      ]
    }
    protectedSettings: {
      commandToExecute: './FRR_BGP_Training_Configuration.sh'
    }
  }
  tags: tagValues
} ]

// module VMs '../../../modules/Microsoft.Compute/VirtualMachine/Linux/Ubuntu24_FRR.bicep' = [ for i in range(1, 4): {
//   name: 'VM0${i}'
//   params: {
//     acceleratedNetworking: acceleratedNetworking
//     location: location
//     subnet_ID: virtualNetwork.properties.subnets[i].id
//     virtualMachine_AdminPassword: virtualMachine_AdminPassword
//     virtualMachine_AdminUsername: virtualMachine_AdminUsername
//     virtualMachine_Name: 'VM0${i}'
//     virtualMachine_Size: virtualMachine_Size
//     privateIPAllocationMethod: 'Static'
//     privateIPAddress: '10.100.${i}.${i}0'
//     addPublicIPAddress: true
//   }
// } ]

module bastion '../../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_name: 'Bastion'
    bastion_SubnetID: virtualNetwork.properties.subnets[0].id
    location: location
    bastion_SKU: 'Basic'
  }
}

// output VM01_PublicIP string = 'ssh -p 2022 ${virtualMachine_AdminUsername}@${VMs[0].outputs.networkInterface_PublicIPAddress}'
// output VM02_PublicIP string = 'ssh -p 2022 ${virtualMachine_AdminUsername}@${VMs[1].outputs.networkInterface_PublicIPAddress}'
// output VM03_PublicIP string = 'ssh -p 2022 ${virtualMachine_AdminUsername}@${VMs[2].outputs.networkInterface_PublicIPAddress}'
// output VM04_PublicIP string = 'ssh -p 2022 ${virtualMachine_AdminUsername}@${VMs[3].outputs.networkInterface_PublicIPAddress}'
