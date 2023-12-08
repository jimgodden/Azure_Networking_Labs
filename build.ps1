$names = @(
    "Azure_ApplicationGateway_Sandbox", 
    "Azure_DNS_Sandbox", 
    "Azure_PrivateLink_Sandbox", 
    "Azure_VirtualWAN_Sandbox", 
    "Azure_VM_to_VM_Sandbox", 
    "TD_Repro")

$names | Foreach-Object -ThrottleLimit 5 -Parallel {
    $path = "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\${PSItem}\src\"
    Write-Host "Building $PSItem" 
    bicep build "${path}main.bicep" --outfile "${path}main.json"
}


$branchName = "main"

$originalURL = "https://github.com/jimgodden/Azure_Networking_Labs/blob/${branchName}/TrafficManTest/src/main.json"
$removeBlob = $originalURL.Remove($originalURL.IndexOf("/blob"), 5)
$shortURL = $removeBlob.Substring(14)
$rawURL = "https://raw.githubusercontent${shortURL}"
$encodedURL = [uri]::EscapeDataString($rawURL)

Write-Host "Link for Azure Deploy Button for ${directoryName}"
Write-host "[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/${encodedURL})"