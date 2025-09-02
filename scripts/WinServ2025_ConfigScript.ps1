param (
    [string]$Username, # Deprecated, but kept for backwards compatibility

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

# Disables the initial bootup request to allow telemetry
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows" -Name "OOBE" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE" -Name "DisablePrivacyExperience" -Value 1 -Type DWord

# Skipping the Allow Telemetry popup with the following registry change is bugged right now.  Leaving this commented in case it gets fixed.
# Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 1 -Type DWord
# Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DisableEnterpriseAuthProxy" -Value 1 -Type DWord


# The following skips the first time user experience of Microsoft Edge
$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
$registryName = "HideFirstRunExperience"
$registryValue = 1
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force
}
Set-ItemProperty -Path $registryPath -Name $registryName -Value $registryValue


# npcap for using Wireshark for taking packet captures
Invoke-WebRequest -Uri "https://www.winpcap.org/install/bin/WinPcap_4_1_3.exe" -OutFile "c:\WinPcap_4_1_3.exe"
# Invoke-WebRequest -Uri "https://npcap.com/dist/npcap-1.80.exe" -OutFile "c:\npcap-1.80.exe"

# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# List of applications to install
$packages = @(
    "pstools",
    "wireshark",
    "vscode",
    "notepadplusplus",
    "powershell-core",
    "iperf3"
)

Set-Content -Value $packages -Path "C:\ChocolateyPackages.txt"

# Install applications using Chocolatey
foreach ($package in $packages) {
    choco install $package -y
}

Write-Host "Applications installed successfully." -ForegroundColor Green


# Creates a task that installs the tools when the user logs in
$initTaskName = "Init"
$initTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\WinServ2025_InstallTools.ps1`""
$initTaskTrigger = New-ScheduledTaskTrigger -AtLogon
Register-ScheduledTask -TaskName $initTaskName -Action $initTaskAction  -User "${env:computername}\${Username}" -Trigger $initTaskTrigger -Force

$scriptBlock = {
$chocolateyPackages = Get-Content "C:\ChocolateyPackages.txt"
Write-Host "The following applications have been pre-installed via chocolatey:"
Write-Host $chocolateyPackages

# Creates shortcuts for commonly used tools on the desktop
$DesktopFilePath = "C:\Users\$env:USERNAME\Desktop"
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
Set-Shortcut -ApplicationFilePath "C:\Program Files\Wireshark\Wireshark.exe"  -DestinationFilePath "${DesktopFilePath}/Wireshark.lnk"
Set-Shortcut -ApplicationFilePath "C:\Program Files\WindowsApps\Microsoft.WindowsTerminal_1.18.10301.0_x64__8wekyb3d8bbwe\WindowsTerminal.exe" -DestinationFilePath "${DesktopFilePath}/Windows Terminal.lnk"
Set-Shortcut -ApplicationFilePath "C:\Program Files\Notepad++\notepad++.exe" -DestinationFilePath "${DesktopFilePath}/Notepad++.lnk"
# Set-Shortcut -ApplicationFilePath "C:\Program Files\Microsoft VS Code\Code.exe" -DestinationFilePath "${DesktopFilePath}/Visual Studio Code.lnk"

Write-Host "`n`nTo take packet captures with wireshark, winpcap needs to be installed."
Write-Host "A pop up for installing winpcap will appear momentarily."
Write-Host "Follow the instructions as directed to install winpcap on this machine."
# Installs winpcap for using Wireshark for taking packet captures
c:\WinPcap_4_1_3.exe


# Removes the scheduled task so that it doesn't run again on the next logon
Unregister-ScheduledTask -TaskName "Init" -Confirm:$false

Read-Host -Prompt "Press enter or CTRL + C to close this window."
}

# Adds the script block to a file that will be run on the first logon of the user
Set-Content -Path "C:\WinServ2025_InstallTools.ps1" -Value $scriptBlock.ToString()


# Configures the Virtual Machine as a Web server if the type is WebServer
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

    # Open TCP ports 80, 443, 8080, and 8443 on the firewall
    foreach ($port in @(80, 443, 8080, 8443)) {
        if (-not (Get-NetFirewallRule -DisplayName "Allow inbound TCP port ${port}" -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName "Allow inbound TCP port ${port}" -Direction Inbound -LocalPort $port -Protocol TCP -Action Allow
        }
    }
    New-NetFirewallRule -DisplayName "Allow inbound TCP port ${portHTTP}" -Direction Inbound -LocalPort $portHTTP -Protocol TCP -Action Allow
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
# Configures the Virtual Machine as a DNS server if the type is DNS
elseif ($Type -eq "DNS") {
    Install-WindowsFeature -Name DNS -IncludeManagementTools
    Set-DnsServerForwarder -IPAddress "168.63.129.16"
    
    Import-Module DnsServer
    
    if (($null -ne $SampleDNSZoneName -and $SampleDNSZoneName -ne "ignore") -and ($null -ne $SampleARecord -and $SampleARecord -ne "ignore")) {
        Add-DnsServerPrimaryZone -Name $SampleDNSZoneName -ZoneFile "${SampleDNSZoneName}dns" -IPv4Address $SampleARecord -PassThru 
    }
    
    if (($null -eq $PrivateDNSZone -and $PrivateDNSZone -ne "ignore") -and ($null -eq $ConditionalForwarderIPAddress -and $ConditionalForwarderIPAddress -ne "ignore")) {
        Add-DnsServerConditionalForwarderZone -Name $PrivateDNSZone -MasterServers $ConditionalForwarderIPAddress
    }    
}
