# Removes a Project and all references of it from this Directory

param(
    [Parameter(Mandatory)]
    [string]$ProjectName
)

$projectNames = .\Tools\Get-ProjectNames.ps1

if ($projectNames.contains($ProjectName)) {

    # Removes the Directory whose name matches the Project Name provided
    Remove-Item -Path ".\${ProjectName}" -Recurse
    
    # Removes the Project Name from the BicepProjectList
    .\Tools\Update-BicepProjectList.ps1 -ProjectName $ProjectName -Operation "Remove"
}
else {
    Write-Host "Project Name ${ProjectName} does not exist.  Please choose a Project Name from the list below: "
    foreach ($name in $projectNames) {
        Write-Host $name
    }
}
