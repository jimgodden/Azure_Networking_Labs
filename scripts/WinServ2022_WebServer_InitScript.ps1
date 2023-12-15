param (
    [string]$FQDN
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

# Define variables for the IIS website and certificate
$portHTTP = 80
$portHTTPS = 443
$certName = "MySelfSignedCert"

if ($null -eq $FQDN) {
    $hostHeader = "example.contoso.com"
}
else {
    $hostHeader = $FQDN
}

# Open TCP port 80 on the firewall
New-NetFirewallRule -DisplayName "Allow inbound TCP port ${portHTTP}" -Direction Inbound -LocalPort $portHTTP -Protocol TCP -Action Allow

# Open TCP port 10001 on the firewall
New-NetFirewallRule -DisplayName "Allow inbound TCP port ${portHTTPS}" -Direction Inbound -LocalPort $portHTTPS -Protocol TCP -Action Allow

# Install the IIS server feature
Install-WindowsFeature -Name Web-Server -includeManagementTools

Import-Module WebAdministration

New-WebBinding -Name "Default Web Site HTTP" -Port $portHTTP -Protocol "http" -HostHeader $hostHeader
New-WebBinding -Name "Default Web Site HTTPS" -Port $portHTTPS -Protocol "https" -HostHeader $hostHeader

# Create a self-signed certificate
New-SelfSignedCertificate -DnsName "localhost" -CertStoreLocation "cert:\LocalMachine\My" -FriendlyName $certName

$SSLCert = Get-ChildItem -Path "cert:\LocalMachine\My" | Where-Object {$_.subject -like 'cn=localhost'}
Set-Location "IIS:\sslbindings"
New-Item "!${portHTTPS}!" -value $SSLCert
