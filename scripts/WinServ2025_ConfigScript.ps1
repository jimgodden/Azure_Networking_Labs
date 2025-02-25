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

# Disables the initial bootup request to allow telemetry
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows" -Name "OOBE" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE" -Name "DisablePrivacyExperience" -Value 1 -Type DWord

# Skipping the Allow Telemetry popup with the following registry change is bugged right now.  Leaving this commented in case it gets fixed.
# Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 1 -Type DWord
# Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DisableEnterpriseAuthProxy" -Value 1 -Type DWord


$progressPreference = 'silentlyContinue'
Write-Host "Installing WinGet PowerShell module from PSGallery..."
Install-PackageProvider -Name NuGet -Force | Out-Null
Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -scope AllUsers | Out-Null
Write-Host "Using Repair-WinGetPackageManager cmdlet to bootstrap WinGet..."
Repair-WinGetPackageManager

# npcap for using Wireshark for taking packet captures
Invoke-WebRequest -Uri "https://npcap.com/dist/npcap-1.80.exe" -OutFile "c:\npcap-1.80.exe"

# Creates a task that installs the tools when the user logs in
$initTaskName = "Init"
$initTaskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\WinServ2025_InstallTools.ps1`""
$initTaskTrigger = New-ScheduledTaskTrigger -AtLogon
Register-ScheduledTask -TaskName $initTaskName -Action $initTaskAction  -User "${env:computername}\${Username}" -Trigger $initTaskTrigger -Force

# Creates a script that will be run on the first logon of the user to install the tools and create shortcuts
$scriptBlock = {
$packages = @(
    "wireshark",
    "pstools",
    "vscode",
    "Notepad++.Notepad++",
    "Microsoft.PowerShell",
    "iperf3"
)

Write-Host "This script runs during the first logon of the user and installs the following tools:"
foreach ($package in $packages) {
    Write-Host $package
}
Write-Host "Additionally, you will see a pop up momentarily to install npcap.  Please click 'Next' and 'Install' to complete the installation.  This is necessary for Wireshark to capture packets.`n`n`n"

Start-Sleep -Seconds 10

Write-Host "Attempting to install several tools now using winget.  You may see a few errors before it starts to work.  This is normal.`n`n"


# Installs npcap for using Wireshark for taking packet captures
c:\npcap-1.80.exe

# Installs the tools defined in $packages via winget.
foreach ($package in $packages) {
    $attempt = 0
    $maxAttempts = 100
    $success = $false

    while (-not $success -and $attempt -lt $maxAttempts) {
        try {
            winget install --accept-source-agreements --scope machine $package
            Write-Host "Successfully installed $package"
            $success = $true
        } catch {
            $attempt++
            Write-Host -ForegroundColor Red "`nFailed to install $package. Attempt $attempt of $maxAttempts."
            Write-Host "Error: $_`n"
            if ($attempt -lt $maxAttempts) {
                Start-Sleep -Seconds 5
            }
        }
    }

    if (-not $success) {
        Write-Host -ForegroundColor Red "Failed to install $package after $maxAttempts attempts."
    }
}



# powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\CommonToolInstaller.ps1"

$DesktopFilePath = "C:\Users\$ENV:USERNAME\Desktop"

# Creates shortcuts for commonly used tools on the desktop
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
Set-Shortcut -ApplicationFilePath "C:\Program Files\Microsoft VS Code\Code.exe" -DestinationFilePath "${DesktopFilePath}/Visual Studio Code.lnk"

# Removes the scheduled task so that it doesn't run again on the next logon
Unregister-ScheduledTask -TaskName "Init" -Confirm:$false

Read-Host -Prompt "Press Enter to exit the script"
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
