param (
    [string]$SampleDNSZoneName,
    [string]$SampleHostName,
    [string]$SampleARecord,
    [string]$PrivateDNSZone,
    [string]$ConditionalForwarderIPAddress
)

# Chocolatey installation
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install PowerShell Core
Start-Job -ScriptBlock { choco install powershell-core -y }

# Install Python 3.11
Start-Job -ScriptBlock { choco install python311 -y }

# Install Visual Studio Code
Start-Job -ScriptBlock { choco install vscode -y }

# Install Wireshark
Start-Job -ScriptBlock { choco install wireshark -y }

# Install PsTools
Start-Job -ScriptBlock { choco install pstools -y }

# Wait for all jobs to finish
Get-Job | Wait-Job
# npcap for using Wireshark for taking packet captures
Invoke-WebRequest -Uri "https://npcap.com/dist/npcap-1.75.exe" -OutFile "c:\npcap-1.75.exe"

# Both files are needed for installing Windows Terminal
Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile "c:\Microsoft.VCLibs.x64.14.00.Desktop.appx"
Invoke-WebRequest -Uri "https://github.com/microsoft/terminal/releases/download/v1.16.10261.0/Microsoft.WindowsTerminal_Win10_1.16.10261.0_8wekyb3d8bbwe.msixbundle" -OutFile "c:\Microsoft.WindowsTerminal_Win10_1.16.10261.0_8wekyb3d8bbwe.msixbundle"


New-Item -ItemType Directory -Name Tools -Path "c:\"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2022_InstallTools.ps1" -OutFile "c:\installTools.ps1"

Install-WindowsFeature -Name DNS -IncludeManagementTools
Set-DnsServerForwarder -IPAddress "168.63.129.16"

Import-Module DnsServer

if ($null -ne $SampleDNSZoneName -and $null -ne $SampleDNSZoneName -and $null -ne $SampleARecord) {
    Add-DnsServerPrimaryZone -Name $SampleDNSZoneName -ZoneFile "${SampleDNSZoneName}dns" -PassThru
    Add-DnsServerResourceRecordA -ZoneName $SampleDNSZoneName -Name $SampleHostName -IPv4Address $SampleARecord -CreatePtr
}

if ($null -eq $PrivateDNSZone -and $null -eq $ConditionalForwarderIPAddress) {
    Add-DnsServerConditionalForwarderZone -Name $PrivateDNSZone -MasterServers $ConditionalForwarderIPAddress
}





















