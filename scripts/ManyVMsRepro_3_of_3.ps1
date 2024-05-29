Param(
    [string]$StorageAccountName,
    [string]$StorageAccountKey,
    [string]$ContainerName,
    [string]$PrivateEndpointIP
)

$filesToDownload = @(
    "upload_to_blob.py"
)

foreach ($fileToDownload in $filesToDownload) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/$fileToDownload" -OutFile "c:\$fileToDownload"
}

pip install azure-storage-blob

New-Item -Path C:\ -ItemType Directory -Name "Results"

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
        py.exe c:\upload_to_blob.py --account-name $StorageAccountName --account-key $StorageAccountKey --container-name $ContainerName  --local-file-path $filePath  --blob-name $fileName
    }

    $tcpClient.Close()
    Start-Sleep -Seconds 5
}
