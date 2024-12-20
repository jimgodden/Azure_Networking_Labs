# Description: A simple UDP server that listens on a specified port and sends a response message to the client.
# This is to be used in conjunction with the UDP_Client.ps1 script.

param (
    [int]$UDPPort,
    [string]$ResponseMessage
)

New-NetFirewallRule -DisplayName "Allow inbound UDP port ${UDPPort}" -Direction Inbound -LocalPort $UDPPort -Protocol UDP -Action Allow
$udpClient = New-Object System.Net.Sockets.UdpClient $UDPPort
$endpoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any, $UDPPort)
while ($true) {
    $receivedBytes = $udpClient.Receive([ref]$endpoint)
    $receivedData = [System.Text.Encoding]::ASCII.GetString($receivedBytes)
    Write-Host "Received: $receivedData"
    $responseBytes = [System.Text.Encoding]::ASCII.GetBytes($ResponseMessage)
    $udpClient.Send($responseBytes, $responseBytes.Length, $endpoint)
}
