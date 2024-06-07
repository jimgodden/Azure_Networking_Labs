$subscriptionId = '<subscription_ID_here>'
$tenantId = '<tenant_ID_here>'
$tag = @{ Training = 'PrivateDNSZone' }
$rgName = 'Sandbox'

if (!(Get-Module -ListAvailable -Name Az)) {
    Write-Host "Azure PowerShell module 'Az' is not installed.  Proceeding with installation..`n"
    Install-Module Az -AllowClobber
}

Set-AzContext -Tenant $tenantId -Subscription $subscriptionId

# Get all resources in the resource group with the specified tag
for ($i = 0; $i -lt 10; $i++) {
    $resources = Get-AzResource -ResourceGroupName $rgName -Tag $tag
    foreach($resource in $resources) {
        Write-Host "Attempting to delete $($resource.Name)"
        Remove-AzResource -ResourceId $resource.ResourceId -Force -AsJob
    }
    Start-Sleep -Seconds 120
}
