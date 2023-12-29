param (
    [string]$FQDN
)

Start-Job -ScriptBlock {    
    # Define variables for the IIS website and certificate
    $portHTTP = 80
    $portHTTPS = 443
    $certName = "MySelfSignedCert"
    $FQDN = $using:FQDN

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
}

Start-Job -ScriptBlock {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/Refactoring/scripts/WinServ2022_InitScript.ps1" -OutFile "C:\WinServ2022_InitScript.ps1"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\WinServ2022_InitScript.ps1"
}

Get-Job | Wait-Job
