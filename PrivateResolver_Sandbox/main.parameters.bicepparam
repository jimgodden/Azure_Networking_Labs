using './src/main.bicep' /*Provide a path to a bicep template*/

@description('Azure Datacenter location for the alternative route')
param locationSecondary = 'westus'

@description('Azure Datacenter location for On Prem resources')
param locationOnPrem = 'eastus'

param virtualMachine_AdminUsername = 'jamesgodden'

param virtualMachine_AdminPassword = getSecret('a2c8e9b2-b8d3-4f38-8a72-642d0012c518', 'Main', 'Main-jamesg-kv', 'genericPassword')

param vpn_SharedKey = getSecret('a2c8e9b2-b8d3-4f38-8a72-642d0012c518', 'Main', 'Main-jamesg-kv', 'genericVPNSharedKey')
