param(
    [string]$BranchName
)

$projectPath = "C:\Users\$env:USERNAME\OneDrive - Microsoft\Programming\Azure_Networking_Labs"

$searchString1 = "/main/"
$replaceString1 = "/$BranchName/"

$searchString2 = "%2Fmain%2F"
$replaceString2 = "%2F$BranchName%2F"

$ProjectNames = @(
    "Azure_ApplicationGateway_Sandbox", 
    "Azure_DNS_Sandbox", 
    "Azure_PrivateLink_Sandbox", 
    "Azure_VirtualWAN_Sandbox",
    "Azure_VM_Linux",
    "Azure_VM_to_VM_Sandbox",
    "Azure_VM_Windows",
    "TD_Repro")

function Update-BranchNameReferences {
    param (
        [string]$searchString,
        [string]$replaceString,
        [string]$path
    )

    Get-ChildItem -Path $path -Recurse | ForEach-Object {
        # Check if the file is not a directory
        if (-not $_.PSIsContainer) {

            Write-Host $_.FullName
            # Read the content of the file
            $content = Get-Content $_.FullName -Raw
    
            # Replace the string
            $newContent = $content -replace [regex]::Escape($searchString), $replaceString
    
            # Write the modified content back to the file
            $newContent | Set-Content $_.FullName
        }
    }
}

Update-BranchNameReferences -path $projectPath -searchString $searchString1 -replaceString $replaceString1
Update-BranchNameReferences -path $projectPath -searchString $searchString2 -replaceString $replaceString2

$ProjectNames | Foreach-Object -ThrottleLimit 5 -Parallel {
    $path = "$using:projectPath\${PSItem}"
    Write-Host "Building $PSItem" 
    bicep build "${path}\src\main.bicep" --outfile "${path}\src\main.json"
}


