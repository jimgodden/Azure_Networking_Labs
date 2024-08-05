param (
    [int]$LocalPort
)

Start-Sleep -seconds 600

# Open TCP port $LocalPort on the firewall
New-NetFirewallRule -DisplayName "Allow inbound TCP port ${LocalPort}" -Direction Inbound -LocalPort $LocalPort -Protocol TCP -Action Allow

$localIP = "0.0.0.0"

# Create a TCP listener
$tcpListener = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Parse($localIP), $LocalPort)

# Start listening for incoming connections
$tcpListener.Start()

Write-Host "Listening on port $LocalPort..."

# Accept incoming connections
$tcpClient = $tcpListener.AcceptTcpClient()
$stream = $tcpClient.GetStream()

Write-Host "Connection established."

# Echo received numbers back to the client
while ($true) {
    $buffer = New-Object byte[] 1024
    $stream.Read($buffer, 0, $buffer.Length)
    $receivedNumber = [System.Text.Encoding]::ASCII.GetString($buffer).Trim([char]0)
    Write-Host "Received: $receivedNumber"

    # Send the same number back to the client
    $response = [System.Text.Encoding]::ASCII.GetBytes($receivedNumber)
    $stream.Write($response, 0, $response.Length)
    Write-Host "Sent: $receivedNumber"
}
