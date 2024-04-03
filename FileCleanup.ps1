# List of file extensions to consider
$fileExtensions = @(".txt", ".md", ".bicep", ".bicepparam", ".json", ".ps1", ".sh")

# Function to ensure each file has at least one newline at the end
function Remove-ExtraNewlines {
    param (
        [string]$filePath
    )
    try {
        $content = Get-Content -Path $filePath -Raw
        $content = $content.TrimEnd("`r", "`n")
        Set-Content -Path $filePath -Value $content
    }
    catch {
        Write-Error "Error processing file '$filePath': $_"
    }
}

# Function to process files in a directory and its subdirectories
function Update-Files {
    param (
        [string]$directory
    )
    Get-ChildItem -Path $directory -Recurse | ForEach-Object {
        if (-not $_.FullName.Contains(".git") -and $_ -is [System.IO.FileInfo] -and $fileExtensions -contains $_.Extension.ToLower()) {
            Remove-ExtraNewlines -filePath $_.FullName
        }
    }
}

# Specify the parent directory
$parentDirectory = "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs"

# Process files in the parent directory and its subdirectories
Update-Files -directory $parentDirectory
