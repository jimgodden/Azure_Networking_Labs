$result = Resolve-DnsName microsoft.com -Type A

if ($result.ipaddress) {
    Write-Host "Success"
} else {
    <# Action when all if and elseif conditions are false #>
}