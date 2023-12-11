param(
    [string]$BranchName = "main",
    [string]$DirectoryName
)

$originalURL = "https://github.com/jimgodden/Azure_Networking_Labs/blob/${BranchName}/${DirectoryName}/src/main.json"
$removeBlob = $originalURL.Remove($originalURL.IndexOf("/blob"), 5)
$shortURL = $removeBlob.Substring(14)
$rawURL = "https://raw.githubusercontent${shortURL}"
$encodedURL = [uri]::EscapeDataString($rawURL)

Write-Host "Link for Azure Deploy Button for ${DirectoryName}"
Write-host "[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/${encodedURL})"













