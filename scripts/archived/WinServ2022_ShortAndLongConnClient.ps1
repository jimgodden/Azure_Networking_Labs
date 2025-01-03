# param (
#     [string]$DestinationIP = "13.77.81.16",
#     [int]$DestinationPort = 444
# )

Set-NetTCPSetting -SettingName InternetCustom -DynamicPortRangeStartPort 50000 -DynamicPortRangeNumberOfPorts 1000
$DestinationIP = "13.77.81.16"
$DestinationPort = 444

function Set-TCPConnections {
  param (
    [string]$DestinationIP,
    [int]$DestinationPort,
    [int]$waitTimeSeconds,
    [int]$ThrottleLimit 
  )

  # Long running connections
  1..100000 | Foreach-Object -ThrottleLimit $ThrottleLimit -Parallel {
    #Action that will run in Parallel. Reference the current object via $PSItem and bring in outside variables with $USING:varname



    # Create TCP client object
    $tcpClient = New-Object System.Net.Sockets.TcpClient

    # Connect to the remote host
    $tcpClient.Connect($using:DestinationIP, $using:DestinationPort)

    # Set the TCP keepalive timer
    $tcpClient.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::KeepAlive, $true)

    # Create a network stream for reading and writing
    $stream = $tcpClient.GetStream()

    $counter = 1

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
      Start-Sleep -Seconds $using:waitTimeSeconds
    }

    # $writer = New-Object System.IO.StreamWriter $stream

    # # Function to send and receive packets
    # function SendAndWait($sendPayload, $SleepTimeSeconds) {
    #     $writer.WriteLine($sendPayload)
    #     $writer.Flush()

    #     Start-Sleep $SleepTimeSeconds
    #     return $true

    # }

    # # Payload values
    # $payload = 1

    # while ($payload -le 2) {
    #     # Send and receive the first set of packets
    #     if (SendAndWait $payload $using:waitTimeSeconds) {
    #       # Write-Host "Sent payload $payload and waited $waitTimeSeconds seconds."

    #     } else {
    #       $srcport = $tcpClient.Client.LocalEndPoint
    #       Write-Host "Error occurred when sending payload $payload and sleeping for Ephemeral Port $srcport."
    #     }
    #     $payload++
    # }



    # Close the TCP connection
    $tcpClient.Close()
  }
}



Set-TCPConnections -DestinationIP $DestinationIP -DestinationPort $DestinationPort -waitTimeSeconds 400 -ThrottleLimit 2

Set-TCPConnections -DestinationIP $DestinationIP -DestinationPort $DestinationPort -waitTimeSeconds 1 -ThrottleLimit 50
  
