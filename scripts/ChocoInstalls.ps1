# Downloads packages using Chocolatey after installing chocolatey and restarting.


# # Install PowerShell Core
# Start-Job -ScriptBlock { choco install powershell-core -y }

# # Install Python 3.11
# Start-Job -ScriptBlock { choco install python311 -y }

# # Install Visual Studio Code
# Start-Job -ScriptBlock { choco install vscode -y }

# # Install Wireshark
# Start-Job -ScriptBlock { choco install wireshark -y }

# # Install PsTools
# Start-Job -ScriptBlock { choco install pstools -y }

choco install powershell-core -y
choco install python311 -y
choco install vscode -y
choco install wireshark -y
choco install pstools -y

Unregister-ScheduledTask -TaskName "ChocoInstalls" -Confirm:$false
