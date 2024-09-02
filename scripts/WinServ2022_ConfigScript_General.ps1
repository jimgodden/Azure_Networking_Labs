param (
    [string]$Username
)

Start-Job -ScriptBlock {
    if (Test-Path -Path ".\WinServ2022_InitScript.ps1") {
        Move-Item -Path ".\WinServ2022_InitScript.ps1" -Destination "C:\"
    } else {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2022_InitScript.ps1" -OutFile "C:\WinServ2022_InitScript.ps1"
    }
    # Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2022_InitScript.ps1" -OutFile "C:\WinServ2022_InitScript.ps1"
}
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\WinServ2022_InitScript.ps1" -Username $Username

Restart-Computer
