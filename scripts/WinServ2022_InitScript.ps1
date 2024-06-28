param (
    [string]$Username
)

# Open ICMP on the firewall
New-NetFirewallRule -DisplayName "Allow inbound ICMPv4" -Direction Inbound -Protocol ICMPv4 -IcmpType 8 -Action Allow

# Chocolatey installation
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# List of Scripts that are stored in my GitHub Repository for general use
$filesToDownload = @(
    "WinServ2022_InstallTools.ps1",
    "ChocoInstalls.ps1"
)

# Downloads the general use scripts from the GitHub Repository
foreach ($fileToDownload in $filesToDownload) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/$fileToDownload" -OutFile "c:\$fileToDownload"
}

# npcap for using Wireshark for taking packet captures
Invoke-WebRequest -Uri "https://npcap.com/dist/npcap-1.75.exe" -OutFile "c:\npcap-1.75.exe"

# Both files are needed for installing Windows Terminal
Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile "c:\Microsoft.VCLibs.x64.14.00.Desktop.appx"
Invoke-WebRequest -Uri "https://github.com/microsoft/terminal/releases/download/v1.16.10261.0/Microsoft.WindowsTerminal_Win10_1.16.10261.0_8wekyb3d8bbwe.msixbundle" -OutFile "c:\Microsoft.WindowsTerminal_Win10_1.16.10261.0_8wekyb3d8bbwe.msixbundle"

# Creates a task that installs the tools when the user logs in
$initTaskName = "Init"
$initTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\WinServ2022_InstallTools.ps1`""
$initTaskTrigger = New-ScheduledTaskTrigger -AtLogon
Register-ScheduledTask -TaskName $initTaskName -Action $initTaskAction -Trigger $initTaskTrigger -User $Username -Force

# Creates a task that installs several packages using chocolatey after the computer has been restarted
$currentTimePlusTwoMinutes = (Get-Date).AddMinutes(2)
$chocoTaskName = "ChocoInstalls"
$chocoTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\ChocoInstalls.ps1`""
$chocoTaskTrigger = New-ScheduledTaskTrigger -Once -At $currentTimePlusTwoMinutes
Register-ScheduledTask -TaskName $chocoTaskName -Action $chocoTaskAction -Trigger $chocoTaskTrigger -User "NT AUTHORITY\SYSTEM" -Force
