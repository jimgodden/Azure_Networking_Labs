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

    [Parameter(Mandatory)]
    [string]$Location,
    
    [bool]$DeployWithParamFile = $true,

    [string]$Owner = $env:USERNAME,

    [string]$Project = "unspecified",

    [ValidateSet("1", "2", "3")]
    [string]$ResourceGroupAction
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
if ($DeploymentName_Split.Count -lt 2) {
    Write-Host "Error: DeploymentName must be in format 'Type-Name' (e.g., 'Sandbox-VirtualWAN')" -ForegroundColor Red
    return
}
$D_Type = $DeploymentName_Split[0]
$D_Name = ($DeploymentName_Split[1..($DeploymentName_Split.Count - 1)]) -join "-"

$username = $env:USERNAME
$rgTags = @{ owner = $Owner; project = $Project }

$deploymentFilePath = ".\Deployment_${D_Type}\${D_Name}"
$mainBicepFile = "${deploymentFilePath}\src\main.bicep"
$mainParameterFile = "${deploymentFilePath}\src\main.bicepparam"
$deploymentJsonFile = "${deploymentFilePath}\deployment.json"

# Switches off the Parameter file option in the deployment if the parameter file does not exist
if (!(Test-Path $mainParameterFile)) {
    $DeployWithParamFile = $false
}

# Validate that the main bicep file exists
if (!(Test-Path $mainBicepFile)) {
    Write-Host "Error: Bicep template not found at: $mainBicepFile" -ForegroundColor Red
    return
}

if (Test-Path $deploymentJsonFile) {
    $deploymentJson = Get-Content $deploymentJsonFile | ConvertFrom-Json
    $iteration = [int]$deploymentJson.iteration
    $rgName = "${DeploymentName}_${username}_RG_${iteration}"
}
else {
    $iteration = 1
    $deploymentJson = @{ iteration = $iteration; lastDeploymentTimeMinutes = $null }
    $deploymentJson | ConvertTo-Json | Set-Content -Path $deploymentJsonFile
    $rgName = "${DeploymentName}_${username}_RG_${iteration}"
}

if (Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue) {
    if ($ResourceGroupAction) {
        $response = $ResourceGroupAction
    }
    else {
        $response = Read-Host "Resource Group ${rgName} already exists.  How do you want to handle this?  Below are the options.  Type the corresponding number and enter to choose.

    1 - Delete this Resource Group and create another Resource Group with a higher iteration number.
    2 - Leave this Resource Group alone and create another Resource Group with a higher iteration number.
    3 - Update this Resource Group with the latest changes.
    
    Response: "
    }

    if ($response -eq "1") {
        Write-Host "`nDeleting $rgName"
        Remove-AzResourceGroup -Name $rgName -Force -AsJob
    }
    
    if ($response -eq "1" -or $response -eq "2") {
        if ($response -eq "2") {
            Write-Host "`nDisregarding $rgName"
        }
        $deploymentJson.iteration = $iteration + 1
        $deploymentJson | ConvertTo-Json | Set-Content -Path $deploymentJsonFile
        $iteration = [int]$deploymentJson.iteration
        $rgName = "${DeploymentName}_${username}_RG_${iteration}"
        Write-Host "Creating $rgName"
        New-AzResourceGroup -Name $rgName -Location $Location -Tag $rgTags
    }
    elseif ($response -eq "3") {
        Write-Host "`nUpdating $rgName"
        Set-AzResourceGroup -Name $rgName -Tag $rgTags
    } 
    else {
        Write-Host "Invalid response. Canceling Deployment.." -ForegroundColor Red
        return
    }
} 
else {
    # RG doesn't exist, create it with current iteration (don't increment)
    Write-Host "Creating $rgName"
    New-AzResourceGroup -Name $rgName -Location $Location -Tag $rgTags
}

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
$deploymentTimeMinutes = [math]::Round($stopwatch.Elapsed.TotalMinutes)

Write-Host "Process finished at: $(Get-Date -Format "HH:mm K")"
Write-Host "Total time taken in minutes: $($stopwatch.Elapsed.TotalMinutes)"

Write-Host "Below is a link to the newly created/modified Resource Group: "
Write-Host -ForegroundColor Blue "https://portal.azure.com/#@/resource/subscriptions/$($context.Subscription.Id)/resourceGroups/${rgName}`n"

# Display deployment results in terminal
Write-Host "`n========== Deployment Results =========="
Write-Host "Deployment Name: ${DeploymentName}" -ForegroundColor Cyan
Write-Host "ProvisioningState: $($deployment.ProvisioningState)" -ForegroundColor $(if ($deployment.ProvisioningState -eq 'Succeeded') { 'Green' } else { 'Red' })
Write-Host "Timestamp: $(Get-Date -Format "HH:mm K")"
Write-Host "========================================`n"

# Save deployment time on success
if ($deployment.ProvisioningState -eq 'Succeeded') {
    $deploymentJson = Get-Content $deploymentJsonFile | ConvertFrom-Json
    $deploymentJson.lastDeploymentTimeMinutes = $deploymentTimeMinutes
    $deploymentJson | ConvertTo-Json | Set-Content -Path $deploymentJsonFile
    Write-Host "Deployment time ($deploymentTimeMinutes min) saved to deployment.json" -ForegroundColor Green
}

# Play the alert sound
[System.Media.SystemSounds]::Exclamation.Play()

$deployment.Outputs
