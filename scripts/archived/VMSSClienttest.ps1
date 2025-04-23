# $result = Resolve-DnsName microsoft.com -Type A

# if ($result.ipaddress) {
#     Write-Host "Success"
# } else {
    # Prepare the JSON payload
    $jsonPayload = @{
        issue = $env:COMPUTERNAME
    } | ConvertTo-Json

    # URL of the Flask API endpoint
    $url = "http://10.1.0.250:5000/api/add"

    # Send the POST request
    $response = Invoke-RestMethod -Uri $url -Method Post -Body $jsonPayload -ContentType "application/json"

    # Print the response
    Write-Output $response
    
# }
