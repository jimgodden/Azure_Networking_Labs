# This file will be used for testing purposes until a proper CI/CD pipeline is in place.

param(
    [string]$DeploymentName
)

$deploymentFilePath = ".\${DeploymentName}\"
$mainBicepFile = "${deploymentFilePath}src\main.bicep"
$mainParameterFile = "${deploymentFilePath}main.parameters.bicepparam"
$iterationFile = "${deploymentFilePath}iteration.txt"

if (!(Test-Path $iterationFile)) {
    New-Item -Path $iterationFile
    Set-Content -Path $iterationFile -Value "1"
}

$iteration = [int](Get-Content $iterationFile)
$rgName = "${DeploymentName}_${iteration}"
$location = "eastus2"

if (Get-AzResourceGroup -Name $rgName) {
    $response = Read-Host "Resource Group ${rgName} already exists.  How do you want to handle this?  Below are the options.  Type the corresponding number and enter to choose.

    1 - Delete this Resource Group and create another Resource Group with a higher iteration number.
    2 - Leave this Resource Group alone and create another Resource Group with a higher iteration number.
    3 - Update this Resource Group with the latest changes."

    if ($response -eq "1") {
        Write-Host "`nDeleting $rgName"
        Remove-AzResourceGroup -Name $rgName -Force -AsJob
        Set-Content -Path $iterationFile -Value "$($iteration + 1)"
        $iteration = [int](Get-Content $iterationFile)
        $rgName = "${DeploymentName}_${iteration}"
        Write-Host "Creating $rgName"
    } 
    elseif ($response -eq "2") {
        Write-Host "`nDisregarding $rgName"
        Set-Content -Path $iterationFile -Value "$($iteration + 1)"
        $iteration = [int](Get-Content $iterationFile)
        $rgName = "${DeploymentName}_${iteration}"
        Write-Host "Creating $rgName"
    } 
    elseif ($response -eq "3") {
        Write-Host "`nUpdating $rgName"
    } 
    else {
        Write-Host "Invalid response.  Canceling Deploment.."
        return
    }
} 
else {
    Set-Content -Path $iterationFile -Value "$($iteration + 1)"
    $iteration = [int](Get-Content $iterationFile)
    $rgName = "${DeploymentName}_${iteration}"
}

# Specifies the account and subscription where the deployment will take place.
if (!$subID) {
    $subID = Read-Host "Please enter the Subscription ID that you want to deploy this Resource Group to: "
}
Set-AzContext -Subscription $subID

Write-Host "`nCreating Resource Group ${rgName}"
New-AzResourceGroup -Name $rgName -Location $location

$stopwatch = [system.diagnostics.stopwatch]::StartNew()

Write-Host "`nStarting Bicep Deployment.  Process began at: $(Get-Date -Format "HH:mm K")"

New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile $mainBicepFile -TemplateParameterFile $mainParameterFile

$stopwatch.Stop()

Write-Host "Process finished at: $(Get-Date -Format "HH:mm K")"
Write-Host "Total time taken in minutes: $($stopwatch.Elapsed.TotalMinutes)"
