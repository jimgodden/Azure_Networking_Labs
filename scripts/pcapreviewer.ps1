Param(
    [string]$StorageAccountName,
    [string]$StorageAccountKey,
    [string]$ContainerName
)

$filesToDownload = @(
    "upload_to_blob.py",
    "download_from_blob.py",
    "delete_from_blob.py"
)

foreach ($fileToDownload in $filesToDownload) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/$fileToDownload" -OutFile "c:\$fileToDownload"
}


# Chocolatey installation
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Visual Studio Code
Start-Job -ScriptBlock { choco install vscode -y }

# Install Wireshark
Start-Job -ScriptBlock { choco install wireshark -y }

# Install Python 3.11
Start-Job -ScriptBlock { choco install python311 -y }

# Wait for all jobs to finish
Get-Job | Wait-Job

New-Item -Path C:\ -ItemType Directory -Name "captures"
New-Item -Path C:\ -ItemType Directory -Name "possible"
New-Item -Path C:\ -ItemType Directory -Name "no_problem"

<#
    This script will create a Scheduled task to run a PowerShell script daily and creates 
    a PowerShell script that deletes all items whose last modified date is older than 1 day within a specified folder.

    The script was created for deleting packet capture files that are older than a day so that the hard drive does not fill up.
    However, this script can be used for other purposes as well.
#>

$scriptPath = "C:\ReviewCaptures.ps1"  # Specify the path for the script file
$taskName = "ReviewCaptures"  # Specify the name for the task

$folderPathBase = "C:"
$folderPathOriginalPcaps = "${folderPathBase}\captures"

$filterCriteria = "tcp.flags.reset == 1 and tcp.time_delta < 7 and tcp.time_delta > 4"
$tshark = "C:\Program Files\Wireshark\tshark.exe"

# Create the script file
$scriptContent = @"
pip install azure-storage-blob

py.exe c:\download_from_blob.py --account-name ${StorageAccountName} --account-key ${StorageAccountKey} --container-name ${ContainerName} --local-path ${folderPathOriginalPcaps}


while (`$true) {
    `$files = Get-ChildItem -Path $folderPathOriginalPcaps

    if (`$files.Count -gt 0) {
        Write-Host "Found files."
        `$files | ForEach-Object {
            # Use tshark to filter packets based on the specified criteria
            `$tsharkOutput = "$tshark -r `$(`$_.FullName) -Y ""$filterCriteria"""

            if (`$tsharkOutput) {
                py.exe upload_to_blob.py --account-name $StorageAccountName --account-key $StorageAccountKey --container-name $ContainerName --local-path `$_.FullName --blob-name "potential.pcap"
                Move-Item -Path $_.FullName -Destination "${folderPathBase}/possible"
            }
            else {
                Move-Item -Path $_.FullName -Destination "${folderPathBase}/no_problem"
            }
        }
    } else {
        Write-Host "No files found."
    }
    New-Item -Path C:\ -ItemType File -Name "`$(Get-Date)"
} 
"@

$scriptContent | Set-Content -Path $scriptPath -Force

$currentTimePlusFiveMinutes = (Get-Date).AddMinutes(5)

$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""  # Action to execute the script
$trigger = New-ScheduledTaskTrigger -Once -At $currentTimePlusFiveMinutes -RepetitionInterval ([TimeSpan]::FromMinutes(10))

# Create the task
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -User "NT AUTHORITY\SYSTEM" -Force

Write-Host "Script file created: $scriptPath"
Write-Host "Task scheduler task created: $taskName"


Restart-Computer
