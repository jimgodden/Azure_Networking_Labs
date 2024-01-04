param (
    [Parameter(Mandatory)]
    [string]$ProjectName
)

$jsonPath = ".\ProjectNames.json"

# Load the existing json content
$jsonContent = Get-Content -Path $jsonPath -Raw | ConvertFrom-json

$newKeyValuePair = @{
    "Name" = $ProjectName
}

$jsonContent += $newKeyValuePair

# Convert the updated content back to json and save it
$jsonContent | ConvertTo-json | Set-Content -Path $jsonPath
