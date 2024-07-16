# Removes a Project and all references of it from this Directory

param(
    [Parameter(Mandatory)]
    [string]$ProjectName
)

# Removes the Directory whose name matches the Project Name provided
Remove-Item -Path ".\${ProjectName}"

# Removes the Project Name from the BicepProjectList
.\Tools\Update-BicepProjectList.ps1 -ProjectName $ProjectName -Operation "Remove"
