# Install PowerShell Core
Start-Job -ScriptBlock { choco install powershell-core -y }

# Install Python 3.11
Start-Job -ScriptBlock { choco install python311 -y }

# Install Visual Studio Code
Start-Job -ScriptBlock { choco install vscode -y }

# Install Wireshark
Start-Job -ScriptBlock { choco install wireshark -y }

# Install PsTools
Start-Job -ScriptBlock { choco install pstools -y }

# Wait for all jobs to finish
Get-Job | Wait-Job

Unregister-ScheduledTask -TaskName "ChocoInstalls" -Confirm:$false