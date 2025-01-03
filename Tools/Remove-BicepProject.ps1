# Removes a Project and all references of it from this Directory

param(
    [Parameter(Mandatory)]
    [string]$ProjectName,

    [Parameter(Mandatory)]
    [string]$ProjectType
)

$projectNames = .\Tools\Get-ProjectNames.ps1

if ($projectNames.contains("${ProjectType}-${ProjectName}")) {

    # Removes the Directory whose name matches the Project Name provided
    Remove-Item -Path ".\Deployment_${ProjectType}\${ProjectName}" -Recurse
    Remove-Item -Path ".\${ProjectName}" -Recurse # Testing running it twice to see if that removes the last two folders
    
    # Removes the Project Name from the BicepProjectList
    .\Tools\Update-BicepProjectList.ps1 -ProjectName "${ProjectType}-${ProjectName}" -Operation "Remove"
}
else {
    Write-Host "Project ${ProjectType}-${ProjectName} does not exist.  Please choose a Project from the list below: "
    foreach ($name in $projectNames) {
        Write-Host $name
    }
}
