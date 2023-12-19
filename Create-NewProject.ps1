# Creates an empty Bicep deployment with all of the needed files to get started quickly.

param(
    [string]$ProjectName
)

New-Item -ItemType Directory -Name $ProjectName

New-Item -ItemType Directory -Path ".\$ProjectName" -Name "src"
New-Item -ItemType File -Path ".\$ProjectName\src" -Name "main.bicep"
New-Item -ItemType File -Path ".\$ProjectName\src" -Name "main.json"

New-Item -ItemType File -Path ".\$ProjectName" -Name "${ProjectName}-deployment.ps1"
Set-Content -Path ".\$ProjectName\${ProjectName}-deployment.ps1" -Value ".\deployment.ps1 -DeploymentName $ProjectName"

New-Item -ItemType File -Path ".\$ProjectName" -Name "diagram.drawio.png"

New-Item -ItemType File -Path ".\$ProjectName" -Name "iteration.txt"
Set-Content -Path ".\$ProjectName\iteration.txt" -Value "1"

New-Item -ItemType File -Path ".\$ProjectName" -Name "main.parameters.bicepparam"
$bicepParamInitializer = "using './src/main.bicep' /*Provide a path to a bicep template*/"
Set-Content -Path ".\$ProjectName\main.parameters.bicepparam" -Value $bicepParamInitializer

New-Item -ItemType File -Path ".\$ProjectName" -Name "readme.md"
$deployButton = .\Create-AzureDeployButton.ps1 -DirectoryName $ProjectName
$readmeInitializer = @"
$deployButton


Diagram of the infrastructure

![Diagram of the infrastructure](diagram.drawio.png)
"@
Set-Content -Path ".\$ProjectName\readme.md" -Value $readmeInitializer

Add-Content -Path ".\.gitignore" -Value @"
$ProjectName/iteration.txt
$ProjectName/main.parameters.bicepparam
"@


