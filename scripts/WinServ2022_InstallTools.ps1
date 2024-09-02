$DesktopFilePath = "C:\Users\$ENV:USERNAME\Desktop"

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
Write-Host "Windows Terminal - A new terminal application for Windows"
Write-Host "`nAdditionally, the script will create shortcuts on the desktop for Wireshark and Windows Terminal."

# Package required for installing Windows Terminal
Add-AppxPackage "c:\Microsoft.VCLibs.x64.14.00.Desktop.appx"
Add-AppxPackage "c:\Microsoft.WindowsTerminal_Win10_1.16.10261.0_8wekyb3d8bbwe.msixbundle"

Set-Shortcut -ApplicationFilePath "C:\Program Files\Wireshark\Wireshark.exe"  -DestinationFilePath "${DesktopFilePath}/Wireshark.lnk"
Set-Shortcut -ApplicationFilePath "C:\Program Files\WindowsApps\Microsoft.WindowsTerminal_1.16.10261.0_x64__8wekyb3d8bbwe\wt.exe" -DestinationFilePath "${DesktopFilePath}/Terminal.lnk"

# npcap for using Wireshark for taking packet captures
c:\npcap-1.75.exe

Unregister-ScheduledTask -TaskName "Init" -Confirm:$false
