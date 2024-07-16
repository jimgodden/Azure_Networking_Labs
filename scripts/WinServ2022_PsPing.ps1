param (
    [string]$DestinationIP,
    [int]$DestinationPort
)

Start-Sleep -Seconds 300

while ($true) {    
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.Connect($DestinationIP, $DestinationPort)

    if ($tcpClient.Connected) {
        Write-Host "TCP handshake successful"
    } else {
        Write-Host "TCP handshake failed"
    }

    $tcpClient.Close()

    Start-Sleep -Seconds 2
}
