param (
    [Parameter(Mandatory)]
    [string]$Username,

    [Parameter(Mandatory)]
    [ValidateSet("General", "WebServer", "DNS")]
    [string]$Type,

    # WebServer parameters
    [string]$location,
    [string]$FQDN,

    # DNS parameters
    [string]$SampleDNSZoneName,
    [string]$SampleARecord,
    [string]$PrivateDNSZone,
    [string]$ConditionalForwarderIPAddress
)

Start-Transcript -Path "C:\CustomScriptExtension.log"

$progressPreference = 'silentlyContinue'
Write-Host "Installing WinGet PowerShell module from PSGallery..."
Install-PackageProvider -Name NuGet -Force | Out-Null
Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -scope AllUsers | Out-Null
Write-Host "Using Repair-WinGetPackageManager cmdlet to bootstrap WinGet..."
Repair-WinGetPackageManager

$CommonToolInstallerScript = {$packages = @(
    "wireshark",
    "pstools",
    "vscode",
    "Microsoft.PowerShell",
    "Notepad++.Notepad++",
    "winscp",
    "iperf3",
    "netmon"
)

foreach ($package in $packages) {
    winget install --accept-source-agreements --scope machine $package
} }

Set-Content -Path "C:\CommonToolInstaller.ps1" -Value $CommonToolInstallerScript.ToString()

# npcap for using Wireshark for taking packet captures
Invoke-WebRequest -Uri "https://npcap.com/dist/npcap-1.80.exe" -OutFile "c:\npcap-1.80.exe"

# Creates a task that installs the tools when the user logs in
$initTaskName = "Init"
$initTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\WinServ2025_InstallTools.ps1`""
$initTaskTrigger = New-ScheduledTaskTrigger -AtLogon
Register-ScheduledTask -TaskName $initTaskName -Action $initTaskAction  -User $Username -Trigger $initTaskTrigger -Force

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
Write-Host "This script is installing Npcap for capturing packets via Wireshark"
Write-Host "Additionally, it is calling a script (located on the desktop) that provides a GUI to easily install various tools"

# npcap for using Wireshark for taking packet captures
c:\npcap-1.80.exe

$packages = @(
    "wireshark",
    "pstools",
    "vscode",
    "Microsoft.PowerShell",
    "Notepad++.Notepad++",
    "winscp",
    "iperf3",
    "netmon"
)

foreach ($package in $packages) {
    winget install --accept-source-agreements --scope machine $package
} 

Copy-Item -Path "C:\CommonToolInstaller.ps1" -Destination "${DesktopFilePath}/CommonToolInstaller.ps1"

# Testing calling the script automatically as the user
# powershell -File "C:\CommonToolInstaller.ps1"

# Unregister-ScheduledTask -TaskName "Init" -Confirm:$false
}

Set-Content -Path "C:\WinServ2025_InstallTools.ps1" -Value $scriptBlock.ToString()
    

# Start of the IIS configuration script

if ($Type -eq "WebServer") {
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

    # End of the IIS configuration script

}
elseif ($Type -eq "DNS") {
    # Start of the DNS Server configuration

    Install-WindowsFeature -Name DNS -IncludeManagementTools
    Set-DnsServerForwarder -IPAddress "168.63.129.16"
    
    Import-Module DnsServer
    
    if (($null -ne $SampleDNSZoneName -and $SampleDNSZoneName -ne "ignore") -and ($null -ne $SampleARecord -and $SampleARecord -ne "ignore")) {
        Add-DnsServerPrimaryZone -Name $SampleDNSZoneName -ZoneFile "${SampleDNSZoneName}dns" -IPv4Address $SampleARecord -PassThru 
    }
    
    if (($null -eq $PrivateDNSZone -and $PrivateDNSZone -ne "ignore") -and ($null -eq $ConditionalForwarderIPAddress -and $ConditionalForwarderIPAddress -ne "ignore")) {
        Add-DnsServerConditionalForwarderZone -Name $PrivateDNSZone -MasterServers $ConditionalForwarderIPAddress
    }

    # End of the DNS Server configuration
    
}

Stop-Transcript
