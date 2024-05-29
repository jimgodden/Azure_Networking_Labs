param (
    [string]$StorageAccountName,
    [string]$StorageAccountKey,
    [string]$ContainerName,
    [string]$PrivateEndpointIP
)

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/ManyVMsRepro_2_of_3.ps1" -OutFile "C:\ManyVMsRepro_2_of_3.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ManyVMsRepro_2_of_3.ps1" -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -ContainerName $ContainerName -PrivateEndpointIP $PrivateEndpointIP

Restart-Computer
