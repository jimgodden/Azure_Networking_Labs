# param (
#     [string]$SASURI,
#     [string]$PrivateEndpointIP
# )

param (
    [string]$StorageAccountName,
    [string]$StorageAccountKey0,
    [string]$StorageAccountContainerName,
    [string]$PrivateEndpointIP
)

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

Install-Module -Name Az.Storage -Allowclobber -Force

Import-Module -Name Az.Storage -Force

New-Item -Path C:\ -ItemType Directory -Name "Results"

# $uri = [System.Uri] $SASURI
# $storageAccountName = $uri.DnsSafeHost.Split(".")[0]
# $container = $uri.LocalPath.Substring(1)
# $sasToken = $uri.Query

# $storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasToken

$storageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey0 -Protocol Https

for ($i = 0; $i -lt 10; $i++) {
    $destinationIP = $PrivateEndpointIP
    $destinationPort = 443

    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.Connect($destinationIP, $destinationPort)

    if ($tcpClient.Connected) {
        Write-Host "TCP handshake successful"
    } else {
        Write-Host "TCP handshake failed"
        $fileName = "${env:COMPUTERNAME}.txt"
        $filePath = "C:\Results\${fileName}"
        Set-Content -Path $filePath -Value "${env:COMPUTERNAME} failed at $(Get-Date)"
        Set-AzStorageBlobContent -File $filePath -Container $StorageAccountContainerName -Context $storageContext -Force
        return
    }

    $tcpClient.Close()
    Start-Sleep -Seconds 5
}
