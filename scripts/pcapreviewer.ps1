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

pip install azure-storage-blob

New-Item -Path C:\ -ItemType Directory -Name "captures"
New-Item -Path C:\ -ItemType Directory -Name "possible"
New-Item -Path C:\ -ItemType Directory -Name "no_problem"

Start-Job -ScriptBlock {
    # Set the folder path to search
    $folderPathBase = "C:"
    $folderPathOriginalPcaps = "C:\captures"

    $filterCriteria = "tcp.flags.reset == 1 and tcp.time_delta < 7 and tcp.time_delta > 4"
    $tshark = "C:\Program Files\Wireshark\tshark.exe"

    python.exe c:\download_from_blob.py --account-name $StorageAccountName --account-key $StorageAccountKey --container-name $ContainerName --local-path $folderPathOriginalPcaps


    while ($true) {
        # Get files in the specified folder that are greater than 5 megabytes
        $files = Get-ChildItem -Path $folderPathOriginalPcaps

        if ($files.Count -gt 0) {
            Write-Host "Found files."
            $files | ForEach-Object {
                # Use tshark to filter packets based on the specified criteria
                $tsharkOutput = "$tshark -r $($_.FullName) -Y ""$filterCriteria"""

                if ($tsharkOutput) {
                    Move-Item -Path $_.FullName -Destination "${folderPathBase}/possible"
                }
                else {
                    Move-Item -Path $_.FullName -Destination "${folderPathBase}/no_problem"
                }
            }
        } else {
            Write-Host "No files found."
        }

        Start-Sleep -Seconds 1800
    } 
}


