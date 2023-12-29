Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/Refactoring/scripts/WinServ2022_InstallTools.ps1" -OutFile "C:\WinServ2022_InstallTools.ps1"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/Refactoring/scripts/WinServ2022_InitScript.ps1" -OutFile "C:\WinServ2022_InitScript.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\WinServ2022_InitScript.ps1"

# Creates a task that installs the tools when the user logs in
$initTaskName = "Init"
$initTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\WinServ2022_InstallTools.ps1`""
$initTaskTrigger = New-ScheduledTaskTrigger -AtLogon
Register-ScheduledTask -TaskName $initTaskName -Action $initTaskAction -Trigger $initTaskTrigger -Force

# Creates a task that installs several packages using chocolatey after the computer has been restarted
$currentTimePlusTwoMinutes = (Get-Date).AddMinutes(2)
$chocoTaskName = "ChocoInstalls"
$chocoTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\ChocoInstalls.ps1`""
$chocoTaskTrigger = New-ScheduledTaskTrigger -Once -At $currentTimePlusTwoMinutes
Register-ScheduledTask -TaskName $chocoTaskName -Action $chocoTaskAction -Trigger $chocoTaskTrigger -User "NT AUTHORITY\SYSTEM" -Force

Restart-Computer
