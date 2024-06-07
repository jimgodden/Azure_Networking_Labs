using './src/main.bicep' /*Provide a path to a bicep template*/

@description('Azure Datacenter location for the alternative route')
param locationSecondary = 'westus'

@description('Azure Datacenter location for On Prem resources')
param locationOnPrem = 'eastus'

param virtualMachine_AdminUsername = 'jamesgodden'

param virtualMachine_AdminPassword = getSecret('1a283126-08f5-4fff-8784-19fe92c7422e', 'Main', 'anp-kv-jg', 'genericPassword')

param vpn_SharedKey = getSecret('1a283126-08f5-4fff-8784-19fe92c7422e', 'Main', 'anp-kv-jg', 'genericVPNSharedKey')
