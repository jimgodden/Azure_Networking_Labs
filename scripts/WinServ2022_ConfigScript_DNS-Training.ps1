param (
    [string]$Username,
    [string]$SampleDNSZoneName,
    [string]$SampleARecord,
    [string]$PrivateDNSZone,
    [string]$ConditionalForwarderIPAddress
)

Start-Job -ScriptBlock {

    $SampleDNSZoneName = $using:SampleDNSZoneName
    $SampleARecord = $using:SampleARecord
    $PrivateDNSZone = $using:PrivateDNSZone
    $ConditionalForwarderIPAddress = $using:ConditionalForwarderIPAddress

    Install-WindowsFeature -Name DNS -IncludeManagementTools

    Import-Module DnsServer
}

Start-Job -ScriptBlock {
    if (Test-Path -Path ".\WinServ2022_InitScript.ps1") {
        Move-Item -Path ".\WinServ2022_InitScript.ps1" -Destination "C:\"
    } else {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2022_InitScript.ps1" -OutFile "C:\WinServ2022_InitScript.ps1"
        Start-Sleep -Seconds 5 # Wait for the file to be written to disk
    }
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\WinServ2022_InitScript.ps1" -Username $using:Username
}

Get-Job | Wait-Job

Restart-Computer
