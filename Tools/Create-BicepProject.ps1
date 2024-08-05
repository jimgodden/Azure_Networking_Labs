# Creates an empty Bicep deployment with all of the needed files to get started quickly.

param(
    [Parameter(Mandatory)]
    [string]$ProjectName
)

# Gets the name of the current Git Branch
$BranchName = git rev-parse --abbrev-ref HEAD

# Creates a Directory for the project
New-Item -ItemType Directory -Name $ProjectName

# Creates a Directory and files for the main project file
New-Item -ItemType Directory -Path ".\$ProjectName" -Name "src"
New-Item -ItemType File -Path ".\$ProjectName\src" -Name "main.bicep"
New-Item -ItemType File -Path ".\$ProjectName\src" -Name "main.json"
New-Item -ItemType File -Path ".\$ProjectName\src" -Name "main.bicepparam"

# updates the main.bicepparam file with default information
# Note: parameters must be manually added
$bicepParamInitializer = "using './main.bicep' /*Provide a path to a bicep template*/"
Set-Content -Path ".\$ProjectName\src\main.bicepparam" -Value $bicepParamInitializer

# Creates a placeholder file for a diagram made with the drawio VS Code extension
New-Item -ItemType File -Path ".\$ProjectName" -Name "diagram.drawio.png"

# Creates a file that holds an integer that increments each time the project is deployed.  
# This ensures that the RG name is unique on each deployment
New-Item -ItemType File -Path ".\$ProjectName" -Name "iteration.txt"
Set-Content -Path ".\$ProjectName\iteration.txt" -Value "1"

# Adds a JSON object to a file that maintains a list of all projects
.\Tools\Update-BicepProjectList.ps1 -ProjectName $ProjectName -Operation "Add"

# Creates a Readme.md file with links to the easy deploy button and diagram of the infrastructure
New-Item -ItemType File -Path ".\$ProjectName" -Name "readme.md"
$deployButton = .\Tools\Create-AzureDeployButton.ps1 -BranchName $BranchName -DirectoryName $ProjectName
$readmeInitializer = @"
$deployButton


Diagram of the infrastructure

![Diagram of the infrastructure](diagram.drawio.png)
"@
Set-Content -Path ".\$ProjectName\readme.md" -Value $readmeInitializer
