# Downloads packages using Chocolatey after installing chocolatey and restarting.

choco install powershell-core -y
choco install python311 -y
choco install vscode -y
choco install wireshark -y
choco install pstools -y

Unregister-ScheduledTask -TaskName "ChocoInstalls" -Confirm:$false
