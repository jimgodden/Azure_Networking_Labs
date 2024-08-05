# Either Adds or Removes the Project Name from the Project List

param (
    [Parameter(Mandatory)]
    [string]$ProjectName,

    [Parameter(Mandatory)]
    [ValidateSet('Add', 'Remove')]
    [string]$Operation
)

# Filepath that holds the project names in JSON Object Notation
$jsonPath = ".\Tools\ProjectNames.json"

# Sets the Key Value Pair of the Project
$keyValuePair = @{
    "Name" = $ProjectName
}

# Load the existing json content
$jsonContent = Get-Content -Path $jsonPath -Raw | ConvertFrom-json

# Adds or Removes the Project Name to/from the list depending on the value of $Operation
switch ($Operation) {
    "Add" { $jsonContent += $keyValuePair }
    "Remove" { $jsonContent = $jsonContent | Where-Object { $_.Name -ne $ProjectName } }
    Default {}
}

# Convert the updated content back to json and saves it
$jsonContent | Sort-Object | ConvertTo-json | Set-Content -Path $jsonPath
