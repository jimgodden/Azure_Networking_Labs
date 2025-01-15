param (
    [string]$Username
)

$progressPreference = 'silentlyContinue'
Write-Host "Installing WinGet PowerShell module from PSGallery..."
Install-PackageProvider -Name NuGet -Force | Out-Null
Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -scope AllUsers | Out-Null
Write-Host "Using Repair-WinGetPackageManager cmdlet to bootstrap WinGet..."
Repair-WinGetPackageManager

function Install-WinGetPackage {
    param (
        [string]$PackageName
    )
    winget install --accept-source-agreements --scope machine $PackageName
}

$packages = @(
    "wireshark",
    "vscode",
    "pstools",
    "Microsoft.PowerShell",
    "notepadplusplus",
    "putty",
    "winscp"
)

foreach ($package in $packages) {
    Install-WinGetPackage -PackageName $package
}

# npcap for using Wireshark for taking packet captures
Invoke-WebRequest -Uri "https://npcap.com/dist/npcap-1.80.exe" -OutFile "c:\npcap-1.80.exe"


# Creates a task that installs the tools when the user logs in
$initTaskName = "Init"
$initTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\WinServ2025_InstallTools.ps1`""
$initTaskTrigger = New-ScheduledTaskTrigger -AtLogon
Register-ScheduledTask -TaskName $initTaskName -Action $initTaskAction -Trigger $initTaskTrigger -User $Username -Force

$scriptBlock = {$DesktopFilePath = "C:\Users\$ENV:USERNAME\Desktop"

function Set-Shortcut {
    param (
        [Parameter(Mandatory)]
        [string]$ApplicationFilePath,
        [Parameter(Mandatory)]
        [string]$DestinationFilePath
    )
    $WScriptObj = New-Object -ComObject ("WScript.Shell")
    $shortcut = $WscriptObj.CreateShortcut($DestinationFilePath)
    $shortcut.TargetPath = $ApplicationFilePath
    $shortcut.Save()
}

# ensures that Windows PowerShell is used
Write-Host "This script is installing the following:"
Write-Host "Npcap - So that Wireshark can take packet captures"
Write-Host "`nAdditionally, the script will create shortcuts on the desktop for several applications."

Set-Shortcut -ApplicationFilePath "C:\Program Files\Wireshark\Wireshark.exe"  -DestinationFilePath "${DesktopFilePath}/Wireshark.lnk"
Set-Shortcut -ApplicationFilePath "C:\Program Files\WindowsApps\Microsoft.WindowsTerminal_1.18.10301.0_x64__8wekyb3d8bbwe\WindowsTerminal.exe" -DestinationFilePath "${DesktopFilePath}/Windows Terminal.lnk"
Set-Shortcut -ApplicationFilePath "C:\Program Files\Notepad++\notepad++.exe" -DestinationFilePath "${DesktopFilePath}/Notepad++.lnk"
Set-Shortcut -ApplicationFilePath "C:\Program Files\Microsoft VS Code\Code.exe" -DestinationFilePath "${DesktopFilePath}/Visual Studio Code.lnk"

# npcap for using Wireshark for taking packet captures
c:\npcap-1.80.exe

Unregister-ScheduledTask -TaskName "Init" -Confirm:$false
}

Set-Content -Path "C:\WinServ2025_InstallTools.ps1" -Value $scriptBlock.ToString()
