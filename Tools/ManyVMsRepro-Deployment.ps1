$location = "eastus" -Location "eastus2" -Location "eastus2"
$rgName = "Repro-Infra"
Write-Host "`nCreating Infra Resource Group ${rgName}"
New-AzResourceGroup -Name $rgName -Location $location

Write-Host "`nStarting Bicep Deployment.  Process began at: $(Get-Date -Format "HH:mm K")"

$infraDeployment = New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\ManyVMsInfra\src\main.bicep" -TemplateParameterFile "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\ManyVMsInfra\main.parameters.bicepparam"

Write-Host "Process finished at: $(Get-Date -Format "HH:mm K")"

# Set-AzStorageAccount -ResourceGroupName $rgName -Name $infraDeployment.Outputs.storageAccountName.Value -AllowBlobPublicAccess $true



$subnet_ID = $infraDeployment.Outputs.subnetID.value
$storageAccountName = $infraDeployment.Outputs.storageAccountName.Value
$storageAccountKey0 = $infraDeployment.Outputs.storageAccountKey0.Value
$StorageAccountContainerName = $infraDeployment.Outputs.storageAccountContainerName.Value
$privateEndpointIP = $infraDeployment.Outputs.storageAccountName.Value + ".blob.core.windows.net"

$location = "eastus"
$TemplateFile = "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\ManyVMsRepro\src\main.bicep"
$TemplateParameterFile = "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\ManyVMsRepro\main.parameters.bicepparam"
# $blobSASURI = ""
for ($i = 0; $i -lt 450; $i+=50) {
    $endNumberOfVMs = ($i + 50).ToString()
    $rgName = "Repro-VMs_Attempt6_${i}-${endNumberOfVMs}"

    Write-Host "`nCreating VM Resource Group ${rgName}"
    New-AzResourceGroup -Name $rgName -Location $location

    Write-Host "`nStarting Bicep Deployment.  Process began at: $(Get-Date -Format "HH:mm K")"
    # New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile $TemplateFile -TemplateParameterFile $TemplateParameterFile -startingNumberOfVirtualMachines $i -blobSASURI $blobSASURI -AsJob
    New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile $TemplateFile -TemplateParameterFile $TemplateParameterFile -startingNumberOfVirtualMachines $i -subnet_ID $subnet_ID -storageAccountName $storageAccountName -storageAccountKey0 $storageAccountKey0 -storageAccountContainerName $StorageAccountContainerName -privateEndpointIP $privateEndpointIP -AsJob
    Start-Sleep -Seconds 5
}





# Gets all Azure Resource Groups with the name Sandbox and removes them without waiting for the finish
# $rgs = Get-AzResourceGroup -Name Repro-VMs*
$rgs = Get-AzResourceGroup -Name Repro-*

foreach ($rg in $rgs) {
    $rgName = $rg.ResourceGroupName
    Write-Host "Deleting the following Resource Group: ${rgName}"
    Remove-AzResourceGroup -Name $rgName -Force -AsJob
}
 -Location "eastus2"
