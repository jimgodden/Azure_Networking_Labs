param (
    [string]$Username,
    [string]$FQDN,
    [string]$location
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
    "notepadplusplus"
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


# Start of the IIS configuration script

# Define variables for the IIS website and certificate
$portHTTP = 80
$portHTTPS = 443
$siteName = "TestWebsite"
$certName = "MySelfSignedCert"

# Create a self-signed certificate
$cert = New-SelfSignedCertificate -DnsName "localhost" -CertStoreLocation "cert:\LocalMachine\My" -FriendlyName $certName

if (($null -eq $FQDN) -and ($FQDN -ne "ignore")) {
    $hostHeader = "example.contoso.com"
}
else {
    $hostHeader = $FQDN
}

if ($null -eq $location) {
    $location = "Azure"
}

# Open TCP port 80 on the firewall
New-NetFirewallRule -DisplayName "Allow inbound TCP port ${portHTTP}" -Direction Inbound -LocalPort $portHTTP -Protocol TCP -Action Allow

# Open TCP port 10001 on the firewall
New-NetFirewallRule -DisplayName "Allow inbound TCP port ${portHTTPS}" -Direction Inbound -LocalPort $portHTTPS -Protocol TCP -Action Allow

# Install the IIS server feature
Install-WindowsFeature -Name Web-Server -includeManagementTools

Import-Module WebAdministration

Remove-Website -Name "Default Web Site"

New-Item -ItemType Directory -Name $siteName -Path "C:\"

New-Item -ItemType File -Name "index.html" -Path "C:\$siteName"
Set-Content -Path "C:\$siteName\index.html" -Value "Welcome to $env:COMPUTERNAME in $location"

New-WebSite -Name $siteName -Port $portHTTP -HostHeader $hostHeader -PhysicalPath "C:\$siteName"
New-WebBinding -Name $siteName -Port $portHTTPS -Protocol "https" -HostHeader $hostHeader
(Get-WebBinding -Name $siteName -port $portHTTPS -Protocol "https").AddSslCertificate($cert.Thumbprint, "my")
Start-Website -Name "TestWebsite"
