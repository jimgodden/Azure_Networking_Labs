bicep build .\main.bicep

$originalURL = "https://github.com/jimgodden/Azure_Networking_Labs/blob/main/Azure_AppGW_to_ASE_Sandbox/src/main.json"
$removeBlob = $originalURL.Remove($originalURL.IndexOf("/blob"), 5)
$shortURL = $removeBlob.Substring(14)
$rawURL = "https://raw.githubusercontent${shortURL}"
$encodedURL = [uri]::EscapeDataString($rawURL)

Write-Host "Below is the string needed for the Deploy to Azure button in a readme.md file"
Write-host "[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/${encodedURL})"