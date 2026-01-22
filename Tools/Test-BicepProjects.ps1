$projectPath = "C:\Users\$env:USERNAME\OneDrive - Microsoft\Programming\Azure_Networking_Labs"

$ProjectNames = .\Tools\Get-ProjectNames.ps1

$ProjectNames | Foreach-Object {

    $ProjectName_Split = $PSItem -split "-"
    $Type = $ProjectName_Split[0]
    $Name = $ProjectName_Split[1]
    $path = "$using:projectPath\Deployment_${Type}\${Name}"
    Write-Host "Deploying $PSItem" 
    & "$using:projectPath\Deployment_${Type}\${Name}\deployment.ps1"

    

}