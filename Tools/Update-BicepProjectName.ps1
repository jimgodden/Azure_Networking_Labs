param (
    [Parameter(Mandatory)]
    [string]$OldProjectName,

    [Parameter(Mandatory)]
    [string]$NewProjectName
)

Rename-Item -Path ".\${OldProjectName}" -NewName $NewProjectName
Rename-Item -Path ".\${NewProjectName}\${OldProjectName}-deployment.ps1" -NewName "${NewProjectName}-deployment.ps1"
Set-Content -Path ".\${NewProjectName}\${NewProjectName}-deployment.ps1" -Value ".\Tools\deployment.ps1 -DeploymentName `"${NewProjectName}`" -Location `"eastus2`""


.\Tools\Update-BicepProjectList.ps1 -ProjectName $OldProjectName -Operation "Remove"

.\Tools\Update-BicepProjectList.ps1 -ProjectName $NewProjectName -Operation "Add"
