using './src/main.bicep' /*Provide a path to a bicep template*/

param virtualMachine_AdminUsername = 'jamesgodden'

param virtualMachine_AdminPassword = getSecret('1a283126-08f5-4fff-8784-19fe92c7422e', 'Main', 'anp-kv-jg', 'genericPassword')
