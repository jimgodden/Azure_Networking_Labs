param (
    [string]$SASURI,
    [string]$PrivateEndpointIP
)

Install-Module -Name Az -AllowClobber

Import-Module -Name Az -Force

New-Item -Path C:\ -ItemType Directory -Name "Results"

$uri = [System.Uri] $SASURI
$storageAccountName = $uri.DnsSafeHost.Split(".")[0]
$container = $uri.LocalPath.Substring(1)
$sasToken = $uri.Query

$storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasToken

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
        Set-AzStorageBlobContent -File $filePath -Container $container -Context $storageContext -Force
    }

    $tcpClient.Close()
    Start-Sleep -Seconds 5
}