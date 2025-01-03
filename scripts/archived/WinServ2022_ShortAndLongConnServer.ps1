param (
    [int]$ListeningPort = 444
)

# Open TCP port 444 on the firewall
# New-NetFirewallRule -DisplayName "Allow inbound TCP port ${ListeningPort}" -Direction Inbound -LocalPort $ListeningPort -Protocol TCP -Action Allow

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse("0.0.0.0"), $ListeningPort)
$listener.Start()

function Get-TCPConnection {
    param (
        [System.Net.Sockets.TcpClient]$client
    )

    try {
        $stream = $client.GetStream()

        # # Set a timer to close the connection after 60 seconds
        # $timer = New-Object Timers.Timer
        # $timer.Interval = 60000  # 60 seconds
        # $timer.AutoReset = $false

        # # Define the action to be executed when the timer elapses
        # $timerAction = {
        #     $client.Close()
        #     $timer.Dispose()
        # }

        # # Wire up the Elapsed event
        # $timer.add_Elapsed($timerAction)

        # # Start the timer
        # $timer.Start()

        while ($true) {
            $buffer = New-Object byte[] 1024
            $stream.Read($buffer, 0, $buffer.Length)
            $receivedNumber = [System.Text.Encoding]::ASCII.GetString($buffer).Trim([char]0)
            Write-Host "Received: $receivedNumber"
        
            # Send the same number back to the client
            $response = [System.Text.Encoding]::ASCII.GetBytes($receivedNumber)
            $stream.Write($response, 0, $response.Length)
            Write-Host "Sent: $receivedNumber"
            Start-Sleep -Milliseconds 100  # Adjust the delay as needed
        }

        # while ($true) {
        #     # Respond with an ACK packet
        #     $ackPacket = [byte]0x10  # Change this to the appropriate ACK value
        #     $stream.Write($ackPacket, 0, 1)
        #     Start-Sleep -Milliseconds 100  # Adjust the delay as needed
        # }
    } finally {
        $client.Close()
    }
}

# try {
#     while ($true) {
#         $client = $listener.AcceptTcpClient()
#         Get-TCPConnection -client $client
#     }
# } finally {
#     $listener.Stop()
# }

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        Start-Job -ScriptBlock { param($client) ; Get-TCPConnection -client $using:client } -ArgumentList $client
    }
} finally {
    $listener.Stop()
}
