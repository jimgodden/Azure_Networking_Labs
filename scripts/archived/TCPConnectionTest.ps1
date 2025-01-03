param (
    [string]$IPAddress,
    [string]$TCPPort
)

Start-Job -ScriptBlock {
    while ($true) {
        Test-NetConnection -ComputerName $using:IPAddress -Port $using:Port
        Start-Sleep -Seconds 5
    }
}
