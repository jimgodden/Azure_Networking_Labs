param (
    [string]$StorageAccountName,
    [string]$StorageAccountKey,
    [string]$ContainerName,
    [string]$PrivateEndpointIP
)

# Chocolatey installation
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# List of Scripts that are stored in my GitHub Repository for general use
$filesToDownload = @(
    "ManyVMsRepro_ChocoInstalls.ps1"
)

# Downloads the general use scripts from the GitHub Repository
foreach ($fileToDownload in $filesToDownload) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/$fileToDownload" -OutFile "c:\$fileToDownload"
}

# Creates a task that installs several packages using chocolatey after the computer has been restarted
$currentTimePlusTwoMinutes = (Get-Date).AddMinutes(2)
$chocoTaskName = "ChocoInstalls"
$chocoTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\ChocoInstalls.ps1`""
$chocoTaskTrigger = New-ScheduledTaskTrigger -Once -At $currentTimePlusTwoMinutes
Register-ScheduledTask -TaskName $chocoTaskName -Action $chocoTaskAction -Trigger $chocoTaskTrigger -User "NT AUTHORITY\SYSTEM" -Force

# Creates a task that installs several packages using chocolatey after the computer has been restarted
$timeDelay = (Get-Date).AddMinutes(10)
$TaskName = "ReproIssueAndLog"
$TaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\ManyVMsRepro_3_of_3.ps1 -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -ContainerName $ContainerName -PrivateEndpointIP $PrivateEndpointIP`""
$TaskTrigger = New-ScheduledTaskTrigger -Once -At $timeDelay
Register-ScheduledTask -TaskName $TaskName -Action $TaskAction -Trigger $TaskTrigger -User "NT AUTHORITY\SYSTEM" -Force
