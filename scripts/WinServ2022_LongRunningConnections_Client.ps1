param (
    [string]$DestinationIP,
    [int]$DestinationPort
)

Start-Sleep -seconds 600

$counter = 1

# Create a TCP client socket
$tcpClient = New-Object System.Net.Sockets.TcpClient

# Connect to the destination VM
$tcpClient.Connect($DestinationIP, $DestinationPort)

# Send a sequence of numbers to the server
while ($true) {
    $stream = $tcpClient.GetStream()
    $buffer = [System.Text.Encoding]::ASCII.GetBytes($counter.ToString())
    $stream.Write($buffer, 0, $buffer.Length)
    Write-Host "Sent: $counter"

    # Wait for the server response
    $response = New-Object byte[] $buffer.Length
    $stream.Read($response, 0, $response.Length)
    $responseString = [System.Text.Encoding]::ASCII.GetString($response)
    Write-Host "Received: $responseString"

    # Increment the counter
    $counter++
    Start-Sleep -Seconds 1
}
