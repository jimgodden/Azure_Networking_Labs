param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName
)

$OutputPath = "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\ARM_to_Bicep_conversions"
$armTemplatePath = Join-Path -Path $OutputPath -ChildPath "$ResourceGroupName-arm.json"
$bicepTemplatePath = Join-Path -Path $OutputPath -ChildPath "$ResourceGroupName.bicep"

# Export the resource group to an ARM template
Export-AzResourceGroup -ResourceGroupName $ResourceGroupName -Path $armTemplatePath

# Convert the ARM template to Bicep
az bicep decompile --file $armTemplatePath

Write-Output "ARM template saved to: $armTemplatePath"
Write-Output "Bicep template saved to: $bicepTemplatePath"