bicep build .\main.bicep

$branchName

$originalURL = "https://github.com/jimgodden/Azure_Networking_Labs/blob/main/TrafficManTest/src/main.json"
$removeBlob = $originalURL.Remove($originalURL.IndexOf("/blob"), 5)
$shortURL = $removeBlob.Substring(14)
$rawURL = "https://raw.githubusercontent${shortURL}"
$encodedURL = [uri]::EscapeDataString($rawURL)

Write-Host "Below is the string needed for the Deploy to Azure button in a readme.md file"
Write-host "[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/${encodedURL})"

# Azure ApplicationGateway Sandbox
Write-Host "Building Azure ApplicationGateway Sandbox" 
bicep build "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\Azure_ApplicationGateway_Sandbox\src\main.bicep" --outfile "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\Azure_ApplicationGateway_Sandbox\src\main.json"

# Azure DNS Sandbox
Write-Host "Building Azure DNS Sandbox"
bicep build "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\Azure_DNS_Sandbox\src\main.bicep" --outfile "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\Azure_DNS_Sandbox\src\main.json"

# Azure PrivateLink Sandbox
Write-Host "Building Azure PrivateLink Sandbox" 
bicep build "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\Azure_PrivateLink_Sandbox\src\main.bicep" --outfile "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\Azure_PrivateLink_Sandbox\src\main.json"

# Azure VirtualWAN Sandbox
Write-Host "Building Azure VirtualWAN Sandbox" 
bicep build "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\Azure_VirtualWAN_Sandbox\src\main.bicep" --outfile "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\Azure_VirtualWAN_Sandbox\src\main.json"

# Azure VM to VM Sandbox
Write-Host "Building Azure VM to VM Sandbox" 
bicep build "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\Azure_VM_to_VM_Sandbox\src\main.bicep" --outfile "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\Azure_VM_to_VM_Sandbox\src\main.json"

# TrafficManTest
Write-Host "Building TrafficManTest" 
bicep build "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\TrafficManTest\src\main.bicep" --outfile "C:\Users\jamesgodden\OneDrive - Microsoft\Programming\Azure_Networking_Labs\TrafficManTest\src\main.json"
