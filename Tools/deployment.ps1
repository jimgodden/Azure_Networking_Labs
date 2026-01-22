# This file simplifies Bicep deployment by doing the following:
#   Creates unique Resource Group names
#   Verifies that the Context is set for Azure PowerShell deployments
#   Correctly formulates the deployment command to include all template and parameter files
#   Provides timestamps and timespans to help track the length of time it takes to deploy the resources
#   Provides links to the newly created Resource Group in the Azure Portal
#   Manages the Tenant and Subscription that the resources will be deployed to

param(
    [Parameter(Mandatory)]
    [string]$DeploymentName,

    # [Parameter(Mandatory)]
    # [string]$DeploymentType,

    [Parameter(Mandatory)]
    [string]$Location,
    
    [bool]$DeployWithParamFile = $true,

    [bool]$MaintenanceMode = $false
)

# Verifies that AzContext is set and displays the subscription information to where this deployment will be completed.
if (!($context = Get-AzContext)) {
    Write-Host "Run both Connect-AzAccount and Set-AzContext -Tenant <TenantId> and -Subscription <SubscriptionId>"
    Write-Host "Once both have been completed, run this script again."
    return
}

Write-Host "AzContext is set to the following:"
Write-Host "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id)) | Tenant: $($context.Tenant.Id)`n"

$DeploymentName_Split = $DeploymentName.Split("-")
$D_Type = $DeploymentName_Split[0]
$D_Name = $DeploymentName_Split[1]

$deploymentFilePath = ".\Deployment_${D_Type}\${D_Name}"
$mainBicepFile = "${deploymentFilePath}\src\main.bicep"
$mainParameterFile = "${deploymentFilePath}\src\main.bicepparam"
$iterationFile = "${deploymentFilePath}\iteration.txt"

# Switches off the Parameter file option in the deployment if the parameter file does not exist
if (!(Test-Path $mainParameterFile)) {
    $DeployWithParamFile = $false
}

if (Test-Path $iterationFile) {
    $iteration = [int](Get-Content $iterationFile)
    $rgName = "${DeploymentName}_RG_${iteration}"
}
else {
    $iteration = 1
    New-Item -ItemType File -Path $iterationFile
    Set-Content -Path $iterationFile -Value "${iteration}"
    $rgName = "${DeploymentName}_RG_${iteration}"
}

if (Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue) {
    $response = Read-Host "Resource Group ${rgName} already exists.  How do you want to handle this?  Below are the options.  Type the corresponding number and enter to choose.

    1 - Delete this Resource Group and create another Resource Group with a higher iteration number.
    2 - Leave this Resource Group alone and create another Resource Group with a higher iteration number.
    3 - Update this Resource Group with the latest changes.
    
    Response: "

    if ($response -eq "1") {
        Write-Host "`nDeleting $rgName"
        Remove-AzResourceGroup -Name $rgName -Force -AsJob
        Set-Content -Path $iterationFile -Value "$($iteration + 1)"
        $iteration = [int](Get-Content $iterationFile)
        $rgName = "${DeploymentName}_RG_${iteration}"
        Write-Host "Creating $rgName"
    } 
    elseif ($response -eq "2") {
        Write-Host "`nDisregarding $rgName"
        Set-Content -Path $iterationFile -Value "$($iteration + 1)"
        $iteration = [int](Get-Content $iterationFile)
        $rgName = "${DeploymentName}_RG_${iteration}"
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
    $rgName = "${DeploymentName}_RG_${iteration}"
}

New-AzResourceGroup -Name $rgName -Location $Location

$stopwatch = [system.diagnostics.stopwatch]::StartNew()
Write-Host "`nStarting Bicep Deployment.  Process began at: $(Get-Date -Format "HH:mm K")`n"

Write-Host "The deployment can be monitored by navigating to the URL below: "
Write-Host -ForegroundColor Blue "https://portal.azure.com/#@/resource/subscriptions/$($context.Subscription.Id)/resourceGroups/${rgName}/deployments`n"

if ($DeployWithParamFile) {
    $deployment = New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile $mainBicepFile -TemplateParameterFile $mainParameterFile
}
else {
    $deployment = New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile $mainBicepFile
}

$stopwatch.Stop()

if ($MaintenanceMode) {
    # $deployment.outputs.
}
else {
    Write-Host "Process finished at: $(Get-Date -Format "HH:mm K")"
    Write-Host "Total time taken in minutes: $($stopwatch.Elapsed.TotalMinutes)"

    Write-Host "Below is a link to the newly created/modified Resource Group: "
    Write-Host -ForegroundColor Blue "https://portal.azure.com/#@/resource/subscriptions/$($context.Subscription.Id)/resourceGroups/${rgName}`n"

    # Define the message and title
    $message = "ProvisioningState: $($deployment.ProvisioningState)`nTimestamp: $(Get-Date -Format "HH:mm K")"
    $title = "Bicep Deployment: ${DeploymentName}"

    # Play the alert sound
    [System.Media.SystemSounds]::Exclamation.Play()

    # Show the message box
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($message, $title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Exclamation)

    $deployment.Outputs
}
