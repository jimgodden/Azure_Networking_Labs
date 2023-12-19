Param(
    [string]$StorageAccountName,
    [string]$StorageAccountKey,
    [string]$StorageAccountFileShareName,
    [string]$ScenarioName
)

# Chocolatey installation
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Visual Studio Code
Start-Job -ScriptBlock { choco install vscode -y }

# Install Wireshark
Start-Job -ScriptBlock { choco install wireshark -y }

# Wait for all jobs to finish
Get-Job | Wait-Job

$StorageAccountNameShortened = $StorageAccountName.Split('.')

cmd.exe /C "cmdkey /add:`"${StorageAccountName}`" /user:`"localhost\$($StorageAccountNameShortened[0])`" /pass:`"${StorageAccountKey}`""
New-PSDrive -Name Z -PSProvider FileSystem -Root "\\${StorageAccountName}\${StorageAccountFileShareName}" -Persist

New-Item -ItemType Directory -Path "Z:\" -Name "iwashere"

Start-Job -ScriptBlock {
    # Set the folder path to search
    $folderPathBase = "Z:"
    $folderPathOriginalPcaps = "Z:\$($using:ScenarioName)"

    $folderForCapsWithoutIssues = "NoIssuesFound"

    # Set the size threshold in megabytes
    $sizeThreshold = 5

    $filterCriteria = "tcp.flags.reset == 1 and tcp.time_delta < 7 and tcp.time_delta > 4"
    $tshark = "C:\Program Files\Wireshark\tshark.exe"

    while ($true) {
        # Get files in the specified folder that are greater than 5 megabytes
        $files = Get-ChildItem -Path $folderPathOriginalPcaps | Where-Object { $_.Length -gt ($sizeThreshold * 1MB) }

        if ($files.Count -gt 0) {
            Write-Host "Files larger than $sizeThreshold megabytes found in ${folderPathOriginalPcaps}:"
            $files | ForEach-Object {
                # Use tshark to filter packets based on the specified criteria
                $tsharkOutput = "$tshark -r $($_.FullName) -Y ""$filterCriteria"""

                if ($tsharkOutput) {
                    Move-Item -Path $_.FullName -Destination $folderPathBase
                }
                else {
                    if (!(Test-Path "${folderPathBase}\${folderForCapsWithoutIssues}")) {
                        New-Item -ItemType Directory -Path $folderPathBase -Name $folderForCapsWithoutIssues
                    }
                    Move-Item -Path $_.FullName -Destination "${folderPathBase}\${folderForCapsWithoutIssues}"
                }
            }
        } else {
            Write-Host "No files larger than $sizeThreshold megabytes found in $folderPath."
        }

        Start-Sleep -Seconds 1800
    } 
}


DefaultEndpointsProtocol=https;
AccountName=mainjamesgstorage;
AccountKey=;
EndpointSuffix=core.windows.net


# Define variables
$sasUrl = "https://mainjamesgstorage.blob.core.windows.net/website?sp=racwdli&st=2023-12-15T21:02:50Z&se=2023-12-16T05:02:50Z&spr=https&sv=2022-11-02&sr=c&sig=O8iJU2wL7t0adKR8umoeudIpaMSBgVWlVKyGCI%2FaS8A%3D"

# Get a list of blobs in the container
$blobs = Invoke-RestMethod -Uri $sasUrl -Method Get

# Delete each blob
foreach ($blob in $blobs) {
    $blobName = $blob.Name

    # Construct the URL for blob deletion
    $deleteUrl = "$sasUrl&restype=container&comp=blob&blob=$blobName"
    
    # Send a DELETE request to delete the blob
    Invoke-RestMethod -Uri $deleteUrl -Method Delete
}
