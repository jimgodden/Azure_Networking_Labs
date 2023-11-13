# This file will be used for testing purposes until a proper CI/CD pipeline is in place.

$mainBicepFile = ".\TD_Repro\src\main.bicep"
$mainJSONFile = ".\TD_Repro\src\main.json"
$mainParameterFile = ".\virtualMachines.parameters.json"

$start = get-date -UFormat "%s"

$currentTime = Get-Date -Format "HH:mm K"
Write-Host "Starting Bicep Deployment.  Process began at: ${currentTime}"

Write-Host "`nBuilding main.json from main.bicep.."
bicep build $mainBicepFile --outfile $mainJSONFile

# Specifies the account and subscription where the deployment will take place.
if (!$subID) {
    $subID = Read-Host "Please enter the Subscription ID that you want to deploy this Resource Group to: "
}
Set-AzContext -Subscription $subID


$iteration = "3"
$scenario_Name = "privatelink${3}"
$rgName = "Connection_${scenario_Name}_${iteration}_Sandbox"
$locationA = 'westeurope'
$locationB = 'westeurope'
$randomFiveLetterString = .\scripts\deployment_Scripts\Get-LetterGUID.ps1

# Might have to test with the same size VM the customer uses.
# $virtualMachine_Size = 'Standard_E48s_v5'


$virtualMachine_Size = 'Standard_E4d_v5'

Write-Host "Creating ${rgName}"
New-AzResourceGroup -Name $rgName -Location $locationA

Write-Host "`nStarting Bicep Deployment.."
New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile $mainBicepFile -TemplateParameterFile $mainParameterFile `
    -locationA $locationA -locationB $locationB `
    -virtualMachine_Size $virtualMachine_Size `
    -scenario_Name $scenario_Name
    # -usingAzureFirewall $false
    # -storageAccount_Name "jamesgsa${randomFiveLetterString}"

$end = get-date -UFormat "%s"
$timeTotalSeconds = $end - $start
$timeTotalMinutes = $timeTotalSeconds / 60
$currentTime = Get-Date -Format "HH:mm K"
Write-Host "Process finished at: ${currentTime}"
Write-Host "Total time taken in seconds: ${timeTotalSeconds}"
Write-Host "Total time taken in minutes: ${timeTotalMinutes}"
Read-Host "`nPress any key to exit.."