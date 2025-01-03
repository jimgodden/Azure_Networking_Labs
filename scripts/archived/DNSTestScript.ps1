# Enter the FQDN of your Blob Endpoint for your Storage Account
# It should look similar to the following: <StorageAccountName>.blob.core.windows.net
$storageFQDN = ""

$contosoResult = (Resolve-DNSName contoso.com).ipaddress
$spoke_winClient = (Resolve-DNSName Spoke-WinClient.azure-contoso.com).ipaddress
$storageAccountResult = (Resolve-DNSName $storageFQDN).ipaddress

Write-Host "Result for Contoso.com: ${contosoResult}"
Write-Host "Result for Spoke-WinClient: ${spoke_winClient}"
Write-Host "Result for ${storageFQDN}: ${storageAccountResult}"

Write-Host "These Queries were run at $(Get-Date -AsUTC)"
